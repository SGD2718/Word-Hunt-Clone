import SwiftUI

struct GameOverOverlay: View {
    @ObservedObject var game: WordGameModel

    private var rankedFound: [(word: String, score: Int)] {
        let table = Dictionary(uniqueKeysWithValues: game.solvedWords.map { ($0.word, $0.score) })
        return game.foundWords
            .map { ($0, table[$0] ?? WHWordHuntEngine.shared().score(word: $0)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                if lhs.0.count != rhs.0.count { return lhs.0.count > rhs.0.count }
                return lhs.0 < rhs.0
            }
    }

    var body: some View {
        ZStack {
            GameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("GAME OVER")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(GameColors.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GameColors.duplicate, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)

                ScoreCard(words: game.foundWords.count, score: game.score)

                FoundWordsColumn(rows: rankedFound)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 8) {
                    Button {
                        game.startNewGame()
                    } label: {
                        Text("NEW GAME")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(GameColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(GameColors.validNew, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                    }

                    Button {
                        game.showingSolver = true
                    } label: {
                        Text("VIEW ALL WORDS")
                            .font(.system(size: 15, weight: .black))
                            .foregroundStyle(GameColors.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 2)
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

private struct FoundWordsColumn: View {
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
                            FoundWordRow(word: row.word, score: row.score)
                        }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GameColors.boardInner, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct FoundWordRow: View {
    let word: String
    let score: Int

    var body: some View {
        HStack {
            WordTileLabel(word: word)
            Spacer()
            Text("\(score)")
                .font(.system(size: 17, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
}

struct WordTileLabel: View {
    let word: String

    var body: some View {
        Text(word)
            .font(.system(size: 16, weight: .heavy))
            .foregroundStyle(GameColors.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                LinearGradient(
                    colors: [GameColors.woodHighlight, GameColors.wood],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: RoundedRectangle(cornerRadius: 5)
            )
    }
}
