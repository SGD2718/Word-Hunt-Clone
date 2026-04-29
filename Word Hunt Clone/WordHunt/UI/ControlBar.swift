import SwiftUI

struct ControlBar: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    game.startNewGame()
                }
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GameButtonStyle())

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    game.forceEndRound()
                }
            } label: {
                Label("Reveal", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(GameButtonStyle())
            .disabled(game.isSolving || game.roundState != .active)

            Button {
                game.showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
            .buttonStyle(GameButtonStyle(compact: true))

            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    game.showingSettings = true
                }
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .buttonStyle(GameButtonStyle(compact: true))
        }
    }
}

struct GameButtonStyle: ButtonStyle {
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
                    .fill(Color(red: 0.02, green: 0.24, blue: 0.12).opacity(configuration.isPressed ? 0.72 : 0.92))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
