import SwiftUI

struct WordBitesAllWordsView: View {
    @ObservedObject var game: WordBitesModel
    @Environment(\.dismiss) private var dismiss

    @State private var allWords: [String] = []

    var body: some View {
        ZStack {
            BlueGameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 12) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(BlueGameColors.ink)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.85), in: Circle())
                    }
                    Spacer()
                    Text("\(allWords.count) words")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(allWords, id: \.self) { word in
                            HStack {
                                WordTileLabel(word: word, found: game.foundWordSet.contains(word))
                                Spacer()
                                Text("\(WHWordHuntEngine.shared().score(word: word))")
                                    .font(.system(size: 18, weight: .heavy))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .background(BlueGameColors.boardInner, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            // Compute on background queue — could be a few hundred K word checks.
            let computed = await Task.detached(priority: .userInitiated) {
                game.allFormableWords()
            }.value
            allWords = computed
        }
    }
}
