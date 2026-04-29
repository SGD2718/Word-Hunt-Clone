import SwiftUI

struct WordBitesGameOverOverlay: View {
    @ObservedObject var game: WordBitesModel
    @EnvironmentObject var router: AppRouter

    private var rankedFound: [(word: String, score: Int)] {
        let engine = WHWordHuntEngine.shared()
        return game.foundWords
            .map { ($0, engine.score(word: $0)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
                return lhs.0 < rhs.0
            }
    }

    var body: some View {
        ZStack {
            BlueGameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ScoreCard(words: game.foundWords.count, score: game.score)

                FoundWordsList(rows: rankedFound)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 8) {
                    Button {
                        game.startNewGame()
                    } label: {
                        Text("NEW GAME")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(BlueGameColors.boardInner, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                    }

                    Button {
                        game.showingAllWords = true
                    } label: {
                        Text("VIEW ALL WORDS")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(BlueGameColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
                    }

                    Button {
                        router.goToMenu()
                    } label: {
                        Text("MAIN MENU")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: 380, maxHeight: .infinity)
        }
    }
}

private struct FoundWordsList: View {
    let rows: [(word: String, score: Int)]

    var body: some View {
        Group {
            if rows.isEmpty {
                VStack {
                    Spacer()
                    Text("No words found")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            HStack {
                                WordTileLabel(word: row.word)
                                Spacer()
                                Text("\(row.score)")
                                    .font(.system(size: 17, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BlueGameColors.boardInner, in: RoundedRectangle(cornerRadius: 14))
    }
}
