// MARK: - Metal Terrain Accelerator
// GPU-accelerated heightmap generation and climate simulation
// Falls back to CPU path when Metal is unavailable

#if canImport(Metal)
import Metal
import OutpostCore

/// GPU-accelerated terrain generation using Metal compute shaders
struct MetalTerrainAccelerator: Sendable {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let heightmapPipeline: MTLComputePipelineState
    private let smoothPipeline: MTLComputePipelineState
    private let temperaturePipeline: MTLComputePipelineState
    private let windPipeline: MTLComputePipelineState

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        // Load shader source from bundle resource and compile at runtime
        guard let shaderURL = Bundle.module.url(forResource: "TerrainShaders", withExtension: "metal"),
              let shaderSource = try? String(contentsOf: shaderURL, encoding: .utf8) else {
            return nil
        }

        let options = MTLCompileOptions()
        options.fastMathEnabled = true

        guard let library = try? device.makeLibrary(source: shaderSource, options: options) else {
            return nil
        }

        guard let heightmapFn = library.makeFunction(name: "heightmap_generate"),
              let smoothFn = library.makeFunction(name: "heightmap_smooth"),
              let temperatureFn = library.makeFunction(name: "climate_temperature"),
              let windFn = library.makeFunction(name: "climate_wind") else {
            return nil
        }

        guard let heightmapPipeline = try? device.makeComputePipelineState(function: heightmapFn),
              let smoothPipeline = try? device.makeComputePipelineState(function: smoothFn),
              let temperaturePipeline = try? device.makeComputePipelineState(function: temperatureFn),
              let windPipeline = try? device.makeComputePipelineState(function: windFn) else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.heightmapPipeline = heightmapPipeline
        self.smoothPipeline = smoothPipeline
        self.temperaturePipeline = temperaturePipeline
        self.windPipeline = windPipeline
    }

    // MARK: - Heightmap Generation

    func generateHeightmap(map: inout WorldMap, noise: SimplexNoise) {
        let size = map.size
        let cellCount = size * size

        // Extract data from WorldMap cells
        var elevationIn = [Float](repeating: 0, count: cellCount)
        var stressIn = [Float](repeating: 0, count: cellCount)
        for y in 0..<size {
            for x in 0..<size {
                let idx = y * size + x
                elevationIn[idx] = map[x, y].elevation
                stressIn[idx] = map[x, y].boundaryStress
            }
        }

        let (permTable, gradTable) = extractNoiseTables(noise: noise)

        guard let permBuffer = device.makeBuffer(bytes: permTable, length: permTable.count * MemoryLayout<Int32>.stride, options: .storageModeShared),
              let gradBuffer = device.makeBuffer(bytes: gradTable, length: gradTable.count * MemoryLayout<Float>.stride, options: .storageModeShared),
              let elevInBuffer = device.makeBuffer(bytes: elevationIn, length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let stressBuffer = device.makeBuffer(bytes: stressIn, length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let elevOutBufferA = device.makeBuffer(length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let elevOutBufferB = device.makeBuffer(length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return
        }

        var uniforms = HeightmapUniforms(mapSize: UInt32(size), invSize: 1.0 / Float(size))

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let threadgroupSize = computeThreadgroupSize(pipeline: heightmapPipeline)
        let gridSize = MTLSize(width: size, height: size, depth: 1)

        // Dispatch heightmap generation
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(heightmapPipeline)
            encoder.setBuffer(permBuffer, offset: 0, index: 0)
            encoder.setBuffer(gradBuffer, offset: 0, index: 1)
            encoder.setBuffer(elevInBuffer, offset: 0, index: 2)
            encoder.setBuffer(stressBuffer, offset: 0, index: 3)
            encoder.setBuffer(elevOutBufferA, offset: 0, index: 4)
            encoder.setBytes(&uniforms, length: MemoryLayout<HeightmapUniforms>.stride, index: 5)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }

        // Dispatch 2 smoothing passes (ping-pong between A and B)
        var smoothUniforms = HeightmapUniforms(mapSize: UInt32(size), invSize: 1.0 / Float(size))

        // Pass 1: A → B
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(smoothPipeline)
            encoder.setBuffer(elevOutBufferA, offset: 0, index: 0)
            encoder.setBuffer(elevOutBufferB, offset: 0, index: 1)
            encoder.setBytes(&smoothUniforms, length: MemoryLayout<HeightmapUniforms>.stride, index: 2)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }

        // Pass 2: B → A
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(smoothPipeline)
            encoder.setBuffer(elevOutBufferB, offset: 0, index: 0)
            encoder.setBuffer(elevOutBufferA, offset: 0, index: 1)
            encoder.setBytes(&smoothUniforms, length: MemoryLayout<HeightmapUniforms>.stride, index: 2)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // Read results back (final result is in buffer A after ping-pong)
        let resultPtr = elevOutBufferA.contents().bindMemory(to: Float.self, capacity: cellCount)
        for y in 0..<size {
            for x in 0..<size {
                map[x, y].elevation = resultPtr[y * size + x]
            }
        }
    }

    // MARK: - Climate: Temperature and Wind

    func generateTemperatureAndWind(map: inout WorldMap, noise: SimplexNoise) {
        let size = map.size
        let cellCount = size * size

        var elevationData = [Float](repeating: 0, count: cellCount)
        for y in 0..<size {
            for x in 0..<size {
                elevationData[y * size + x] = map[x, y].elevation
            }
        }

        let (permTable, gradTable) = extractNoiseTables(noise: noise)

        guard let elevBuffer = device.makeBuffer(bytes: elevationData, length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let permBuffer = device.makeBuffer(bytes: permTable, length: permTable.count * MemoryLayout<Int32>.stride, options: .storageModeShared),
              let gradBuffer = device.makeBuffer(bytes: gradTable, length: gradTable.count * MemoryLayout<Float>.stride, options: .storageModeShared),
              let tempBuffer = device.makeBuffer(length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let windXBuffer = device.makeBuffer(length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared),
              let windYBuffer = device.makeBuffer(length: cellCount * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            return
        }

        var climateUniforms = ClimateUniforms(mapSize: UInt32(size), invSize: 1.0 / Float(size))

        let threadgroupSize = computeThreadgroupSize(pipeline: temperaturePipeline)
        let gridSize = MTLSize(width: size, height: size, depth: 1)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        // Temperature kernel
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(temperaturePipeline)
            encoder.setBuffer(elevBuffer, offset: 0, index: 0)
            encoder.setBuffer(permBuffer, offset: 0, index: 1)
            encoder.setBuffer(gradBuffer, offset: 0, index: 2)
            encoder.setBuffer(tempBuffer, offset: 0, index: 3)
            encoder.setBytes(&climateUniforms, length: MemoryLayout<ClimateUniforms>.stride, index: 4)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }

        // Wind kernel
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(windPipeline)
            encoder.setBuffer(elevBuffer, offset: 0, index: 0)
            encoder.setBuffer(windXBuffer, offset: 0, index: 1)
            encoder.setBuffer(windYBuffer, offset: 0, index: 2)
            encoder.setBytes(&climateUniforms, length: MemoryLayout<ClimateUniforms>.stride, index: 3)
            encoder.dispatchThreads(gridSize, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let tempPtr = tempBuffer.contents().bindMemory(to: Float.self, capacity: cellCount)
        let windXPtr = windXBuffer.contents().bindMemory(to: Float.self, capacity: cellCount)
        let windYPtr = windYBuffer.contents().bindMemory(to: Float.self, capacity: cellCount)

        for y in 0..<size {
            for x in 0..<size {
                let idx = y * size + x
                map[x, y].temperature = tempPtr[idx]
                map[x, y].windX = windXPtr[idx]
                map[x, y].windY = windYPtr[idx]
            }
        }
    }

    // MARK: - Helpers

    private func extractNoiseTables(noise: SimplexNoise) -> (perm: [Int32], grad: [Float]) {
        let permTable = noise.perm.prefix(512).map { Int32($0) }
        // Convert permGrad2 tuples to interleaved float2 array for Metal
        var gradTable = [Float](repeating: 0, count: 512 * 2)
        for i in 0..<min(noise.permGrad2.count, 512) {
            gradTable[i * 2] = Float(noise.permGrad2[i].0)
            gradTable[i * 2 + 1] = Float(noise.permGrad2[i].1)
        }
        return (Array(permTable), gradTable)
    }

    private func computeThreadgroupSize(pipeline: MTLComputePipelineState) -> MTLSize {
        let maxThreads = pipeline.maxTotalThreadsPerThreadgroup
        let threadWidth = pipeline.threadExecutionWidth
        let threadsPerGroup = min(maxThreads, 256)
        let groupWidth = threadWidth
        let groupHeight = threadsPerGroup / groupWidth
        return MTLSize(width: groupWidth, height: max(groupHeight, 1), depth: 1)
    }
}

// MARK: - Uniform Structs (must match Metal shader layout)

private struct HeightmapUniforms {
    let mapSize: UInt32
    let invSize: Float
}

private struct ClimateUniforms {
    let mapSize: UInt32
    let invSize: Float
}

#endif
