import SwiftUI

struct SolverReviewView: View {
    @ObservedObject var game: WordGameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Score")
                        Spacer()
                        Text("\(game.score)")
                            .fontWeight(.bold)
                    }
                    HStack {
                        Text("Found")
                        Spacer()
                        Text("\(game.foundWords.count) / \(game.solvedWords.count)")
                            .fontWeight(.bold)
                    }
                }

                Section("Best Words") {
                    ForEach(game.solvedWords, id: \.word) { result in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(result.word)
                                    .font(.headline)
                                Text(pathText(result.path))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(result.score)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(game.foundWordSet.contains(result.word) ? .green : .primary)
                        }
                    }
                }
            }
            .navigationTitle("Solver Review")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        game.startNewGame()
                    } label: {
                        Label("New Game", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
    }

    private func pathText(_ path: [NSNumber]) -> String {
        path.map { number in
            let index = number.intValue
            let row = index / 4 + 1
            let column = index % 4 + 1
            return "\(row),\(column)"
        }
        .joined(separator: " -> ")
    }
}
