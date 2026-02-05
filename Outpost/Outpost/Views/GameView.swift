import SwiftUI
import SpriteKit

/// Main game view containing SpriteKit scene and SwiftUI overlays
struct GameView: View {
    @Bindable var viewModel: SimulationViewModel

    @State private var scene: GameScene?

    var body: some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: gameScene)
                .ignoresSafeArea()

            // SwiftUI overlays
            VStack(spacing: 0) {
                // Top header bar
                HeaderBar(viewModel: viewModel)

                Spacer()

                // Bottom controls and panels
                HStack(alignment: .bottom, spacing: 12) {
                    // Event log on left
                    EventLogPanel(events: viewModel.recentEvents)
                        .frame(maxWidth: 300)

                    Spacer()

                    // Unit detail panel on right (if unit selected)
                    if viewModel.selectedUnitId != nil {
                        UnitDetailPanel(viewModel: viewModel)
                            .frame(maxWidth: 280)
                    }
                }
                .padding(.horizontal)

                // Bottom controls
                ControlsView(viewModel: viewModel)
            }
        }
        .onAppear {
            setupSceneCallbacks()
            viewModel.startSimulation()
        }
        .onChange(of: viewModel.currentTick) { _, _ in
            updateScene()
        }
        .onChange(of: viewModel.selectedUnitId) { _, _ in
            updateScene()
        }
    }

    private var gameScene: GameScene {
        if let existing = scene {
            return existing
        }
        let newScene = GameScene(size: CGSize(width: 800, height: 600))
        newScene.scaleMode = .resizeFill
        DispatchQueue.main.async {
            scene = newScene
            setupSceneCallbacks()
        }
        return newScene
    }

    private func setupSceneCallbacks() {
        scene?.onUnitSelected = { unitId in
            viewModel.selectedUnitId = unitId
        }
    }

    private func updateScene() {
        guard let snapshot = viewModel.worldSnapshot else { return }
        scene?.updateWorld(with: snapshot, selectedUnitId: viewModel.selectedUnitId)
    }
}

#Preview {
    GameView(viewModel: SimulationViewModel())
}
