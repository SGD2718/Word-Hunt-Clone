import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var router: AppRouter
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.30, blue: 0.45),
                    Color(red: 0.10, green: 0.18, blue: 0.28),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Text("WORD GAMES")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 2)

                VStack(spacing: 18) {
                    GameMenuCard(
                        title: "Word Hunt",
                        subtitle: "Connect adjacent letters to form words.",
                        gradient: [
                            Color(red: 0.45, green: 0.62, blue: 0.40),
                            Color(red: 0.28, green: 0.45, blue: 0.28),
                        ],
                        previewLetters: ["W", "O", "R", "D"]
                    ) {
                        router.go(.wordHunt)
                    }

                    GameMenuCard(
                        title: "Word Bites",
                        subtitle: "Drag blocks to line up words.",
                        gradient: [
                            Color(red: 0.27, green: 0.50, blue: 0.70),
                            Color(red: 0.14, green: 0.28, blue: 0.42),
                        ],
                        previewLetters: ["B", "I", "T", "E"]
                    ) {
                        router.go(.wordBites)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                            showingSettings = true
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(12)
                            .background(.white.opacity(0.12), in: Circle())
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                Spacer()
            }

            SettingsOverlay(isPresented: $showingSettings)
                .zIndex(3)
        }
    }
}

private struct GameMenuCard: View {
    let title: String
    let subtitle: String
    let gradient: [Color]
    let previewLetters: [String]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                HStack(spacing: 4) {
                    ForEach(Array(previewLetters.enumerated()), id: \.offset) { _, letter in
                        Text(letter)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(BlueGameColors.ink)
                            .frame(width: 26, height: 26)
                            .background(
                                LinearGradient(
                                    colors: [BlueGameColors.woodHighlight, BlueGameColors.wood],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(18)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 18)
            )
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
