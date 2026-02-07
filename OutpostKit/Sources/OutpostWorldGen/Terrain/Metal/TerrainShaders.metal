// MARK: - Terrain Compute Shaders
// Metal GPU kernels for heightmap generation and climate simulation
// Ports of SimplexNoise + NoiseUtilities from Swift to Metal

#include <metal_stdlib>
using namespace metal;

// MARK: - Constants

constant float F2 = 0.36602540378f;  // 0.5 * (sqrt(3) - 1)
constant float G2 = 0.21132486540f;  // (3 - sqrt(3)) / 6

// MARK: - Uniforms

struct HeightmapUniforms {
    uint mapSize;
    float invSize;
};

struct ClimateUniforms {
    uint mapSize;
    float invSize;
};

// MARK: - Simplex Noise 2D (OpenSimplex2 port)

static int fastFloor(float x) {
    int xi = int(x);
    return x < float(xi) ? xi - 1 : xi;
}

static float noise2D(float2 pos,
                     constant int *perm,
                     constant float2 *grad) {
    float x = pos.x;
    float y = pos.y;

    float s = (x + y) * F2;
    int i = fastFloor(x + s);
    int j = fastFloor(y + s);

    float t = float(i + j) * G2;
    float x0 = x - (float(i) - t);
    float y0 = y - (float(j) - t);

    int i1, j1;
    if (x0 > y0) { i1 = 1; j1 = 0; }
    else          { i1 = 0; j1 = 1; }

    float x1 = x0 - float(i1) + G2;
    float y1 = y0 - float(j1) + G2;
    float x2 = x0 - 1.0f + 2.0f * G2;
    float y2 = y0 - 1.0f + 2.0f * G2;

    int ii = i & 255;
    int jj = j & 255;

    float n0 = 0.0f, n1 = 0.0f, n2 = 0.0f;

    float t0 = 0.5f - x0 * x0 - y0 * y0;
    if (t0 >= 0.0f) {
        t0 *= t0;
        float2 g = grad[ii + perm[jj]];
        n0 = t0 * t0 * (g.x * x0 + g.y * y0);
    }

    float t1 = 0.5f - x1 * x1 - y1 * y1;
    if (t1 >= 0.0f) {
        t1 *= t1;
        float2 g = grad[ii + i1 + perm[jj + j1]];
        n1 = t1 * t1 * (g.x * x1 + g.y * y1);
    }

    float t2 = 0.5f - x2 * x2 - y2 * y2;
    if (t2 >= 0.0f) {
        t2 *= t2;
        float2 g = grad[ii + 1 + perm[jj + 1]];
        n2 = t2 * t2 * (g.x * x2 + g.y * y2);
    }

    return 70.0f * (n0 + n1 + n2);
}

// MARK: - Noise Compositors

static float fbm(float2 pos, int octaves, float frequency, float lacunarity, float persistence,
                 constant int *perm, constant float2 *grad) {
    float value = 0.0f;
    float amplitude = 1.0f;
    float freq = frequency;
    float maxAmplitude = 0.0f;

    for (int i = 0; i < octaves; i++) {
        value += noise2D(pos * freq, perm, grad) * amplitude;
        maxAmplitude += amplitude;
        amplitude *= persistence;
        freq *= lacunarity;
    }

    return value / maxAmplitude;
}

static float ridgedMultifractal(float2 pos, int octaves, float frequency, float lacunarity, float gain,
                                constant int *perm, constant float2 *grad) {
    float value = 0.0f;
    float weight = 1.0f;
    float freq = frequency;

    for (int i = 0; i < octaves; i++) {
        float signal = noise2D(pos * freq, perm, grad);
        signal = 1.0f - abs(signal);
        signal *= signal;
        signal *= weight;
        weight = clamp(signal * gain, 0.0f, 1.0f);
        value += signal;
        freq *= lacunarity;
    }

    return value / float(octaves) * 1.25f;
}

static float domainWarp(float2 pos, float frequency, float warpStrength, int octaves,
                        constant int *perm, constant float2 *grad) {
    float warpX = fbm(pos + float2(0.0f, 0.0f), octaves, frequency, 2.0f, 0.5f, perm, grad);
    float warpY = fbm(pos + float2(5.2f, 1.3f), octaves, frequency, 2.0f, 0.5f, perm, grad);

    return fbm(pos + float2(warpX, warpY) * warpStrength, octaves, frequency, 2.0f, 0.5f, perm, grad);
}

static float smoothstepCustom(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0f, 1.0f);
    return t * t * (3.0f - 2.0f * t);
}

// MARK: - Kernel 1: Heightmap Generation

kernel void heightmap_generate(
    constant int *perm [[buffer(0)]],
    constant float2 *grad [[buffer(1)]],
    constant float *elevation_in [[buffer(2)]],
    constant float *boundaryStress [[buffer(3)]],
    device float *elevation_out [[buffer(4)]],
    constant HeightmapUniforms &uniforms [[buffer(5)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint size = uniforms.mapSize;
    if (gid.x >= size || gid.y >= size) return;

    uint idx = gid.y * size + gid.x;
    float invSize = uniforms.invSize;
    float nx = float(gid.x) * invSize;
    float ny = float(gid.y) * invSize;
    float2 pos = float2(nx, ny);

    // Base continental shape using fBm (6 octaves)
    float baseNoise = fbm(pos, 6, 3.0f, 2.0f, 0.5f, perm, grad);

    // Mountain ridges using ridged multifractal (5 octaves)
    float ridgeNoise = ridgedMultifractal(pos, 5, 2.0f, 2.2f, 2.0f, perm, grad);

    // Domain-warped detail for organic feel (3 octaves)
    float2 warpPos = pos + float2(100.0f, 100.0f);
    float warpedDetail = domainWarp(warpPos, 4.0f, 0.3f, 3, perm, grad);

    // Get tectonic coarse elevation and stress
    float tectonicElev = elevation_in[idx];
    float stress = boundaryStress[idx];

    // Blend: tectonic provides large-scale shape, noise adds detail
    float elevation = tectonicElev * 0.5f                    // 50% tectonic
        + (baseNoise * 0.5f + 0.5f) * 0.25f                 // 25% fBm continents
        + ridgeNoise * stress * 0.15f                        // 15% ridges at boundaries
        + warpedDetail * 0.1f;                               // 10% organic detail

    // Edge falloff — push edges toward ocean
    float fSize = float(size);
    float margin = fSize * 0.1f;
    float fx = float(gid.x);
    float fy = float(gid.y);

    float left = smoothstepCustom(0.0f, margin, fx);
    float right = smoothstepCustom(0.0f, margin, fSize - fx);
    float top = smoothstepCustom(0.0f, margin, fy);
    float bottom = smoothstepCustom(0.0f, margin, fSize - fy);
    float edgeFalloff = min(min(left, right), min(top, bottom));

    elevation *= edgeFalloff;
    elevation = clamp(elevation, 0.0f, 1.0f);

    elevation_out[idx] = elevation;
}

// MARK: - Kernel 2: Heightmap Smoothing (3x3 box blur)

kernel void heightmap_smooth(
    constant float *input [[buffer(0)]],
    device float *output [[buffer(1)]],
    constant HeightmapUniforms &uniforms [[buffer(2)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint size = uniforms.mapSize;
    if (gid.x >= size || gid.y >= size) return;

    uint idx = gid.y * size + gid.x;
    float sum = 0.0f;
    float count = 0.0f;

    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            int nx = int(gid.x) + dx;
            int ny = int(gid.y) + dy;
            if (nx >= 0 && nx < int(size) && ny >= 0 && ny < int(size)) {
                sum += input[uint(ny) * size + uint(nx)];
                count += 1.0f;
            }
        }
    }

    // 60% original + 40% neighbor average
    output[idx] = input[idx] * 0.6f + (sum / count) * 0.4f;
}

// MARK: - Kernel 3: Climate Temperature

kernel void climate_temperature(
    constant float *elevation [[buffer(0)]],
    constant int *perm [[buffer(1)]],
    constant float2 *grad [[buffer(2)]],
    device float *temperature_out [[buffer(3)]],
    constant ClimateUniforms &uniforms [[buffer(4)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint size = uniforms.mapSize;
    if (gid.x >= size || gid.y >= size) return;

    uint idx = gid.y * size + gid.x;
    float invSize = uniforms.invSize;

    // Latitude effect: warm at equator, cold at poles
    float normalizedY = float(gid.y) * invSize;
    float latitudeTemp = 1.0f - 2.0f * abs(normalizedY - 0.5f);

    // Elevation cooling
    float elev = elevation[idx];
    float elevationCooling = max(0.0f, elev - 0.3f) * 1.5f;

    // Noise variation
    float nx = float(gid.x) * invSize;
    float ny = normalizedY;
    float2 tempPos = float2(nx * 4.0f + 200.0f, ny * 4.0f + 200.0f);
    float tempNoise = noise2D(tempPos, perm, grad) * 0.1f;

    float temp = latitudeTemp - elevationCooling + tempNoise;

    // Ocean moderating effect
    if (elev < 0.3f) {
        float oceanModerate = (0.3f - elev) / 0.3f;
        temp = temp * (1.0f - oceanModerate * 0.3f) + 0.5f * oceanModerate * 0.3f;
    }

    temperature_out[idx] = clamp(temp, 0.0f, 1.0f);
}

// MARK: - Kernel 4: Climate Wind

kernel void climate_wind(
    constant float *elevation [[buffer(0)]],
    device float *windX_out [[buffer(1)]],
    device float *windY_out [[buffer(2)]],
    constant ClimateUniforms &uniforms [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    uint size = uniforms.mapSize;
    if (gid.x >= size || gid.y >= size) return;

    uint idx = gid.y * size + gid.x;
    float invSize = 1.0f / float(size);
    float normalizedY = float(gid.y) * invSize;

    float latFromEquator = abs(normalizedY - 0.5f) * 2.0f;

    float wx, wy;

    if (latFromEquator > 0.7f) {
        // Polar easterlies
        wx = normalizedY < 0.5f ? -0.5f : 0.5f;
        wy = normalizedY < 0.5f ? 0.3f : -0.3f;
    } else if (latFromEquator > 0.2f) {
        // Westerlies
        wx = normalizedY < 0.5f ? 0.8f : -0.8f;
        wy = normalizedY < 0.5f ? -0.2f : 0.2f;
    } else {
        // Trade winds / equatorial
        wx = normalizedY < 0.5f ? -0.6f : 0.6f;
        wy = 0.0f;
    }

    // Terrain deflection
    float elev = elevation[idx];
    if (elev > 0.5f) {
        float reduction = (elev - 0.5f) * 2.0f;
        wx *= (1.0f - reduction * 0.5f);
        wy *= (1.0f - reduction * 0.5f);
    }

    windX_out[idx] = wx;
    windY_out[idx] = wy;
}
