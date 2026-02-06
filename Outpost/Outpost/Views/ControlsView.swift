import SwiftUI

/// Bottom control bar for simulation control
struct ControlsView: View {
    @Bindable var viewModel: SimulationViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Play/Pause button
            Button(action: { viewModel.toggleSimulation() }) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .background(viewModel.isRunning ? Color.orange : Color.green)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }

            // Step button (when paused)
            if !viewModel.isRunning {
                Button(action: { viewModel.stepSimulation() }) {
                    Image(systemName: "forward.frame.fill")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }

            Divider()
                .frame(height: 32)

            // Speed slider
            VStack(alignment: .leading, spacing: 2) {
                Text("Speed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "tortoise.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Slider(
                        value: $viewModel.ticksPerSecond,
                        in: 1...60,
                        step: 1
                    )
                    .frame(width: 120)

                    Image(systemName: "hare.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text("\(Int(viewModel.ticksPerSecond))/s")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
            }

            Divider()
                .frame(height: 32)

            Button(action: { viewModel.enhancedAnimations.toggle() }) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(viewModel.enhancedAnimations ? .yellow : .secondary)
            }
            .help("Toggle enhanced animations")

            Spacer()

            // Clear selection button
            if viewModel.selectedUnitId != nil {
                Button(action: { viewModel.clearSelection() }) {
                    Label("Clear Selection", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    VStack {
        Spacer()
        ControlsView(viewModel: SimulationViewModel())
    }
}
