import SwiftUI

struct StartOverlay: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        ZStack {
            GameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("WORD HUNT")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                Text("Connect adjacent letters to form words.\nFind as many as you can in 80 seconds.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        game.beginRound()
                    }
                } label: {
                    Text("Start")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(minWidth: 180)
                        .padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 3)
                }
                .disabled(game.isGeneratingBoard)
                .opacity(game.isGeneratingBoard ? 0.6 : 1)
            }
            .padding(28)
            .padding(.horizontal, 30)
        }
    }
}
