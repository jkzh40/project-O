import SwiftUI

/// Top header bar showing simulation stats
struct HeaderBar: View {
    @Bindable var viewModel: SimulationViewModel

    var body: some View {
        HStack(spacing: 16) {
            // Tick counter
            StatBadge(
                icon: "clock.fill",
                label: "Tick",
                value: "\(viewModel.currentTick)"
            )

            Divider()
                .frame(height: 24)

            // Population
            StatBadge(
                icon: "person.2.fill",
                label: "Dwarves",
                value: "\(viewModel.dwarfCount)",
                color: .blue
            )

            // Hostiles
            if viewModel.hostileCount > 0 {
                StatBadge(
                    icon: "exclamationmark.triangle.fill",
                    label: "Hostiles",
                    value: "\(viewModel.hostileCount)",
                    color: .red
                )
            }

            Spacer()

            // Z-Level controls
            HStack(spacing: 8) {
                Button(action: { viewModel.moveZLevelDown() }) {
                    Image(systemName: "arrow.down")
                        .font(.caption.bold())
                }
                .disabled(viewModel.currentZ <= 0)

                Text("Z: \(viewModel.currentZ)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)

                Button(action: { viewModel.moveZLevelUp() }) {
                    Image(systemName: "arrow.up")
                        .font(.caption.bold())
                }
                .disabled(viewModel.currentZ >= (viewModel.worldSnapshot?.depth ?? 1) - 1)
            }
            .padding(.horizontal, 8)

            // Running indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.isRunning ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(viewModel.isRunning ? "Running" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

/// Individual stat badge
struct StatBadge: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.monospaced().bold())
            }
        }
    }
}

#Preview {
    VStack {
        HeaderBar(viewModel: SimulationViewModel())
        Spacer()
    }
}
