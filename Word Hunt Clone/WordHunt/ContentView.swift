import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @ObservedObject var game: WordGameModel
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var boardFrameSide: CGFloat {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first
        let size = scene?.screen.bounds.size ?? UIScreen.main.bounds.size
        let shortSide = min(size.width, size.height)
        // Tile span = 2/3 of screen short dim. Board frame adds 22pt for the
        // dark-green inner padding (matches `tileLength`'s `- 22` in WordBoardView).
        return shortSide * (2.0 / 3.0) + 22
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GameColors.boardBackground
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    GameTitleBar()

                    ScoreStrip(game: game)
                        .padding(.horizontal, 12)

                    WordToastLayer(game: game)
                        .frame(height: 56)
                        .padding(.top, 2)

                    WordBoardView(game: game)
                        .frame(width: boardFrameSide, height: boardFrameSide)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .scaleEffect(game.boardPulse == 0 ? 1 : 1.01)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: game.boardPulse)

                    Spacer(minLength: 0)

                    ControlBar(game: game)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                .padding(.top, 10)
                .padding(.horizontal, 8)
                .frame(maxWidth: 520)

                if game.roundState == .preRound {
                    StartOverlay(game: game)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }

                if game.roundState == .ended {
                    GameOverOverlay(game: game)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: game.roundState)
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.15)) {
                    game.tick()
                }
            }
            .sheet(isPresented: $game.showingSolver) {
                SolverReviewView(game: game)
            }
            .sheet(isPresented: $game.showingAbout) {
                AboutView(info: game.dictionaryInfo, seed: game.seed)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(game: WordGameModel())
    }
}
