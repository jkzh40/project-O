import SwiftUI
import OCore

/// Panel showing details of the selected unit
struct UnitDetailPanel: View {
    @Bindable var viewModel: SimulationViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let detail = viewModel.getSelectedUnitDetail() {
                // Header
                HStack {
                    // Creature indicator
                    Circle()
                        .fill(creatureColor(for: detail.creatureType))
                        .frame(width: 16, height: 16)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(detail.name)
                            .font(.caption.bold())
                        Text(detail.creatureType.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // State badge
                    Text(detail.state.rawValue.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(stateColor(for: detail.state).opacity(0.3))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                // Stats
                VStack(spacing: 8) {
                    // Health
                    StatBar(
                        label: "Health",
                        icon: "heart.fill",
                        value: detail.healthPercent,
                        color: healthColor(detail.healthPercent),
                        text: "\(detail.healthCurrent)/\(detail.healthMax)"
                    )

                    // Hunger
                    StatBar(
                        label: "Hunger",
                        icon: "fork.knife",
                        value: detail.hungerPercent,
                        color: needColor(detail.hungerPercent),
                        text: detail.hungerPercent > 50 ? "Hungry" : "Fed"
                    )

                    // Thirst
                    StatBar(
                        label: "Thirst",
                        icon: "drop.fill",
                        value: detail.thirstPercent,
                        color: needColor(detail.thirstPercent),
                        text: detail.thirstPercent > 50 ? "Thirsty" : "Hydrated"
                    )

                    // Drowsiness
                    StatBar(
                        label: "Fatigue",
                        icon: "bed.double.fill",
                        value: detail.drowsinessPercent,
                        color: needColor(detail.drowsinessPercent),
                        text: detail.drowsinessPercent > 50 ? "Tired" : "Rested"
                    )
                }
                .padding(12)

                Divider()

                // Position info
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Position: \(detail.position)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .rotationEffect(facingAngle(for: detail.facing))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                // Memories section
                if !detail.recentMemories.isEmpty || !detail.topBeliefs.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                            Text("Memories")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                        }

                        // Recent memories
                        if !detail.recentMemories.isEmpty {
                            ForEach(Array(detail.recentMemories.enumerated()), id: \.offset) { _, memory in
                                Text(memory)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        // Beliefs
                        if !detail.topBeliefs.isEmpty {
                            Text("Beliefs:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            ForEach(Array(detail.topBeliefs.enumerated()), id: \.offset) { _, belief in
                                Text(belief)
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .lineLimit(1)
                            }
                        }

                        // Emotional associations
                        if !detail.positiveAssociations.isEmpty || !detail.negativeAssociations.isEmpty {
                            Text("Feelings:")
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                            ForEach(Array(detail.positiveAssociations.enumerated()), id: \.offset) { _, assoc in
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.green)
                                    Text("\(assoc.name) +\(assoc.feeling)")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                            }
                            ForEach(Array(detail.negativeAssociations.enumerated()), id: \.offset) { _, assoc in
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.red)
                                    Text("\(assoc.name) \(assoc.feeling)")
                                        .font(.caption2)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }

            } else {
                Text("No unit selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Functions

    private func creatureColor(for type: CreatureType) -> Color {
        switch type {
        case .orc:
            return Color(red: 0.85, green: 0.7, blue: 0.55)
        case .goblin:
            return Color(red: 0.3, green: 0.5, blue: 0.3)
        case .wolf:
            return .gray
        case .bear:
            return Color(red: 0.4, green: 0.25, blue: 0.15)
        case .giant:
            return Color(red: 0.5, green: 0.4, blue: 0.5)
        case .undead:
            return Color(red: 0.4, green: 0.5, blue: 0.4)
        }
    }

    private func stateColor(for state: UnitState) -> Color {
        switch state {
        case .idle: return .gray
        case .moving: return .blue
        case .working: return .orange
        case .eating: return .yellow
        case .drinking: return .cyan
        case .sleeping: return .purple
        case .socializing: return .pink
        case .fighting: return .red
        case .fleeing: return .yellow
        case .unconscious: return .brown
        case .dead: return .black
        }
    }

    private func healthColor(_ percent: Int) -> Color {
        if percent > 75 { return .green }
        if percent > 50 { return .yellow }
        if percent > 25 { return .orange }
        return .red
    }

    private func needColor(_ percent: Int) -> Color {
        if percent < 25 { return .green }
        if percent < 50 { return .yellow }
        if percent < 75 { return .orange }
        return .red
    }

    private func facingAngle(for direction: Direction) -> Angle {
        switch direction {
        case .north: return .degrees(0)
        case .northeast: return .degrees(45)
        case .east: return .degrees(90)
        case .southeast: return .degrees(135)
        case .south: return .degrees(180)
        case .southwest: return .degrees(225)
        case .west: return .degrees(270)
        case .northwest: return .degrees(315)
        }
    }
}

/// Horizontal stat bar with icon, label, and progress
struct StatBar: View {
    let label: String
    let icon: String
    let value: Int
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(value) / 100)
                }
            }
            .frame(height: 8)

            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

#Preview {
    UnitDetailPanel(viewModel: SimulationViewModel())
        .frame(width: 280)
        .padding()
}
