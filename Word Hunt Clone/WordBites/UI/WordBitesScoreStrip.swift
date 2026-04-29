import SwiftUI

struct WordBitesScoreStrip: View {
    @ObservedObject var game: WordBitesModel

    var body: some View {
        VStack(spacing: 6) {
            ScoreCard(words: game.foundWords.count, score: game.score)
            HStack {
                Spacer(minLength: 0)
                BitesTimerPill(text: timeText, urgent: game.remainingSeconds <= 10)
            }
        }
    }

    private var timeText: String {
        let minutes = game.remainingSeconds / 60
        let seconds = game.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct BitesTimerPill: View {
    let text: String
    let urgent: Bool

    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .heavy))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.5))
            )
    }
}
