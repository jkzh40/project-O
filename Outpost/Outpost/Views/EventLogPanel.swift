import SwiftUI

/// Scrolling panel showing recent simulation events
struct EventLogPanel: View {
    let events: [String]

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.caption)
                    Text("Events")
                        .font(.caption.bold())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            if isExpanded {
                Divider()

                // Event list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(events.enumerated().reversed()), id: \.offset) { index, event in
                                EventRow(event: event)
                                    .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 200)
                    .onChange(of: events.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo(events.count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Single event row
struct EventRow: View {
    let event: String

    var body: some View {
        Text(event)
            .font(.caption2.monospaced())
            .foregroundStyle(eventColor)
            .lineLimit(2)
    }

    private var eventColor: Color {
        if event.contains("died") || event.contains("KILLED") {
            return .red
        } else if event.contains("CRIT") || event.contains("hit") {
            return .orange
        } else if event.contains("married") || event.contains("born") {
            return .pink
        } else if event.contains("migrated") || event.contains("arrived") {
            return .green
        } else if event.contains("completed") {
            return .blue
        } else {
            return .secondary
        }
    }
}

#Preview {
    EventLogPanel(events: [
        "Urist arrived",
        "Doren seeking food",
        "Morul completed mining",
        "goblin appeared!",
        "Urist hit goblin for 15 slash damage"
    ])
    .padding()
    .frame(width: 300)
}
