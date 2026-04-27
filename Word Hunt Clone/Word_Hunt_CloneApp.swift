//
//  Word_Hunt_CloneApp.swift
//  Word Hunt Clone
//
//  Created by Benjamin Lee on 4/26/26.
//

import SwiftUI

@main
struct Word_Hunt_CloneApp: App {
    @StateObject private var game = WordGameModel()

    var body: some Scene {
        WindowGroup {
            ContentView(game: game)
        }
    }
}
