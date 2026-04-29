import SwiftUI

struct SolverReviewView: View {
    @ObservedObject var game: WordGameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(GameColors.ink)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.85), in: Circle())
                    }
                    Spacer()
                    Text("\(game.solvedWords.count) words")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(game.solvedWords, id: \.word) { result in
                            HStack {
                                WordTileLabel(word: result.word, found: game.foundWordSet.contains(result.word))
                                Spacer()
                                Text("\(result.score)")
                                    .font(.system(size: 18, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(GameColors.boardInner, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}
