import SwiftUI

struct WordBitesToastLayer: View {
    @ObservedObject var game: WordBitesModel
    let cellSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(game.releasedToasts) { toast in
                BitesToastChip(toast: toast, cellSize: cellSize)
                    .id(toast.id)
            }
        }
    }
}

struct BitesToastChip: View {
    let toast: WordBitesModel.WordToast
    let cellSize: CGFloat

    @State private var startDate: Date = Date()

    private let totalDuration: Double = 2.0
    private let growDuration: Double = 0.5
    private let fadeDuration: Double = 0.5
    private let endScaleMultiplier: CGFloat = 3.5
    private let riseCells: CGFloat = 0.875

    private var startScale: CGFloat {
        // 4-letter "WORD (+400)" chip natural width ≈ 110pt; target = cellSize / 3.
        let baseWidth: CGFloat = 110
        let target = cellSize / 3
        return max(0.05, target / baseWidth)
    }

    private var anchorX: CGFloat {
        if toast.isHorizontal {
            return CGFloat(toast.col) * cellSize + CGFloat(toast.length) * cellSize / 2
        }
        return CGFloat(toast.col) * cellSize + cellSize / 2
    }

    private var anchorY: CGFloat {
        CGFloat(toast.row) * cellSize - 2
    }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(startDate)
            let t = max(0, min(elapsed, totalDuration))
            let growT = min(t / growDuration, 1.0)
            let scale = startScale + (startScale * endScaleMultiplier - startScale) * CGFloat(growT)
            let rise = CGFloat(t / totalDuration) * riseCells * cellSize
            let fadeStart = totalDuration - fadeDuration
            let opacity: Double = t < fadeStart ? 1.0 : max(0.0, 1.0 - (t - fadeStart) / fadeDuration)

            return HStack(spacing: 4) {
                Text(toast.text)
                if toast.score > 0 {
                    Text("(+\(toast.score))")
                }
            }
            .font(.system(size: 22, weight: .black, design: .rounded))
            .foregroundStyle(BlueGameColors.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            .lineLimit(1)
            .fixedSize()
            .scaleEffect(scale, anchor: .bottom)
            .opacity(opacity)
            .position(x: anchorX, y: anchorY - rise)
        }
    }
}
