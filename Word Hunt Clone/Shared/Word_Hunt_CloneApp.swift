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
        switch router.screen {
        case .menu:
            MainMenuView()
        case .wordHunt:
            WordHuntScreen()
        case .wordBites:
            WordBitesScreen()
        }
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
