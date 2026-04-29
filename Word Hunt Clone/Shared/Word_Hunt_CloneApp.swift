//
//  Word_Hunt_CloneApp.swift
//  Word Hunt Clone
//
//  Created by Benjamin Lee on 4/26/26.
//

import SwiftUI

@main
struct Word_Hunt_CloneApp: App {
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            // Menu sits at the back. It doesn't move; the game screen slides
            // up over it when entering and slides down off the bottom when
            // returning to the menu.
            MainMenuView()

            switch router.screen {
            case .menu:
                EmptyView()
            case .wordHunt:
                WordHuntScreen()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            case .wordBites:
                WordBitesScreen()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.86), value: router.screen)
    }
}

private struct WordHuntScreen: View {
    @StateObject private var game = WordGameModel()
    var body: some View {
        ContentView(game: game)
    }
}

private struct WordBitesScreen: View {
    @StateObject private var game = WordBitesModel()
    var body: some View {
        WordBitesContentView(game: game)
    }
}
