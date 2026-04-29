import SwiftUI

struct WordBitesControlBar: View {
    @ObservedObject var game: WordBitesModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    game.startNewGame()
                }
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(BitesButtonStyle())

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    game.endRound()
                }
            } label: {
                Label("End Round", systemImage: "flag.checkered")
            }
            .buttonStyle(BitesButtonStyle())
            .disabled(game.roundState != .active)

            Button {
                game.showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
            .buttonStyle(BitesButtonStyle(compact: true))
        }
    }
}

struct BitesButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: compact ? 92 : .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(BlueGameColors.boardInner.opacity(configuration.isPressed ? 0.72 : 0.92))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
