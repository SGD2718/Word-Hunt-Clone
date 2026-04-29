import SwiftUI

struct GameTitleBar: View {
    var title: String = "WORD HUNT"

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 10, height: 10)
            Text(title)
                .font(.system(size: 31, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 10, height: 10)
        }
        .padding(.top, 6)
        .accessibilityAddTraits(.isHeader)
    }
}
