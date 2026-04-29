import SwiftUI

struct ScoreStrip: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        VStack(spacing: 6) {
            ScoreCard(words: game.foundWords.count, score: game.score)
            HStack {
                Spacer(minLength: 0)
                TimerPill(text: timeText, urgent: game.remainingSeconds <= 10)
            }
        }
    }

    private var timeText: String {
        let minutes = game.remainingSeconds / 60
        let seconds = game.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ScoreCard: View {
    let words: Int
    let score: Int

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.black)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 0) {
                Text("WORDS: \(words)")
                    .font(.system(size: 16, weight: .bold))
                Text("SCORE: \(scoreText)")
                    .font(.system(size: 34, weight: .heavy))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundStyle(GameColors.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
    }

    private var scoreText: String {
        String(format: "%04d", score)
    }
}

struct TimerPill: View {
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
