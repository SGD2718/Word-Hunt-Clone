import SwiftUI

struct WordToastLayer: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        ZStack {
            ForEach(game.releasedToasts) { toast in
                ReleasedToastView(toast: toast)
                    .id(toast.id)
            }

            if !game.selectedPath.isEmpty {
                WordChip(text: game.currentWord, status: game.liveStatus, score: liveScore)
                    .id("live")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.18, dampingFraction: 0.85), value: game.selectedPath)
    }

    private var liveScore: Int {
        guard game.liveStatus == .acceptedNew else { return 0 }
        return WHWordHuntEngine.shared().score(word: game.currentWord)
    }
}

struct ReleasedToastView: View {
    let toast: WordGameModel.WordToast
    @State private var phase: CGFloat = 0

    var body: some View {
        WordChip(text: toast.text, status: toast.status, score: toast.score)
            .scaleEffect(scale)
            .opacity(1.0 - phase)
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    phase = 1.0
                }
            }
    }

    private var scale: CGFloat {
        let target: CGFloat = toast.status == .acceptedNew ? 1.25 : 1.0
        return 1 + (target - 1) * phase
    }
}

struct WordChip: View {
    let text: String
    let status: WordGameModel.LiveStatus
    let score: Int

    var body: some View {
        Group {
            if !text.isEmpty {
                HStack(spacing: 4) {
                    Text(text)
                    if score > 0 {
                        Text("(+\(score))")
                    }
                }
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(GameColors.toastInk)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(background.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
    }

    private var background: Color {
        switch status {
        case .acceptedNew:
            return GameColors.toastValidBackground
        case .duplicate:
            return GameColors.toastDuplicateBackground
        case .empty, .invalid:
            return GameColors.toastInvalidBackground
        }
    }
}
