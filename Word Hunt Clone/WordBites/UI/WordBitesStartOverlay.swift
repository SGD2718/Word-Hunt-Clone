import SwiftUI

struct WordBitesStartOverlay: View {
    @ObservedObject var game: WordBitesModel
    @EnvironmentObject var router: AppRouter

    var body: some View {
        ZStack {
            BlueGameColors.boardBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("WORD BITES")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                Text("Drag blocks onto the grid.\nLine up letters horizontally or vertically\nto form words. 80 seconds.")
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

                Button {
                    router.goToMenu()
                } label: {
                    Text("Main Menu")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(minWidth: 180)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        )
                }
            }
            .padding(28)
            .padding(.horizontal, 30)
        }
    }
}
