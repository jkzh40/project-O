//
//  ContentView.swift
//  Outpost
//
//  Created by Jack Zhao on 2/4/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = SimulationViewModel()

    var body: some View {
        GameView(viewModel: viewModel)
            #if os(iOS)
            .statusBarHidden()
            #endif
    }
}

#Preview {
    ContentView()
}
