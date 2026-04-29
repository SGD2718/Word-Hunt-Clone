import SwiftUI
import UIKit
import Combine

struct WordBitesContentView: View {
    @ObservedObject var game: WordBitesModel
    @EnvironmentObject var router: AppRouter
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var screenWidth: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let size = scene?.screen.bounds.size ?? UIScreen.main.bounds.size
        return min(size.width, size.height)
    }

    private var cellSize: CGFloat {
        // Fit 8 cells across with some side padding.
        let usable = screenWidth - 12
        return floor(usable / 8.0)
    }

    var body: some View {
        ZStack {
            BlueGameColors.boardInner
                .ignoresSafeArea()

            GridBackgroundView(cellSize: cellSize, lineColor: Color.white.opacity(0.05), tintCells: false)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                GameTitleBar(title: "WORD BITES")

                WordBitesScoreStrip(game: game)
                    .padding(.horizontal, 12)

                Spacer(minLength: 0)

                WordBitesBoardView(game: game, cellSize: cellSize)
                    .scaleEffect(game.boardPulse == 0 ? 1 : 1.01)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: game.boardPulse)

                Spacer(minLength: 0)

                WordBitesControlBar(game: game)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
            .padding(.top, 10)

            if game.roundState == .preRound {
                WordBitesStartOverlay(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            if game.roundState == .ended {
                WordBitesGameOverOverlay(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }

            SettingsOverlay(isPresented: $game.showingSettings)
                .zIndex(3)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.roundState)
        .onReceive(timer) { _ in
            withAnimation(.linear(duration: 0.15)) {
                game.tick()
            }
        }
        .sheet(isPresented: $game.showingAbout) {
            AboutView(info: WHWordHuntEngine.shared().dictionaryInfo, seed: game.seed)
        }
        .sheet(isPresented: $game.showingAllWords) {
            WordBitesAllWordsView(game: game)
        }
    }
}
