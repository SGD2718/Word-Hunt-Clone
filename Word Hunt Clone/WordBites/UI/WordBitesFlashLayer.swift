import SwiftUI

/// Renders the white "word found" effect as a single glowing block spanning
/// the full word, with all letters inside and a soft outer glow gradient.
struct WordBitesFlashLayer: View {
    @ObservedObject var game: WordBitesModel
    let cellSize: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(game.flashEvents) { event in
                FlashWordView(event: event, cellSize: cellSize)
                    .id(event.id)
            }
        }
    }
}

private struct FlashWordView: View {
    let event: WordBitesModel.FlashEvent
    let cellSize: CGFloat

    @State private var startDate: Date = Date()

    private let total: Double = 1.0
    private let fadeIn: Double = 0.15
    private let hold: Double = 0.20

    private var width: CGFloat {
        event.isHorizontal ? CGFloat(event.cells.count) * cellSize : cellSize
    }

    private var height: CGFloat {
        event.isHorizontal ? cellSize : CGFloat(event.cells.count) * cellSize
    }

    private var centerX: CGFloat {
        if event.isHorizontal {
            return CGFloat(event.col) * cellSize + width / 2
        }
        return CGFloat(event.col) * cellSize + cellSize / 2
    }

    private var centerY: CGFloat {
        if event.isHorizontal {
            return CGFloat(event.row) * cellSize + cellSize / 2
        }
        return CGFloat(event.row) * cellSize + height / 2
    }

    private let inset: CGFloat = 4
    private let glowSpread: CGFloat = 18

    var body: some View {
        TimelineView(.animation) { context in
            let t = max(0, min(context.date.timeIntervalSince(startDate), total))
            let opacity: Double
            if t < fadeIn {
                opacity = t / fadeIn
            } else if t < fadeIn + hold {
                opacity = 1.0
            } else {
                let fadeOut = total - (fadeIn + hold)
                opacity = max(0, 1.0 - (t - fadeIn - hold) / fadeOut)
            }

            return content
                .opacity(opacity)
        }
    }

    private var content: some View {
        let w = width - inset
        let h = height - inset
        let outerW = w + glowSpread * 2
        let outerH = h + glowSpread * 2

        return ZStack {
            // Outer edge glow — softly radiates beyond the white block.
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.55))
                .frame(width: outerW, height: outerH)
                .blur(radius: glowSpread)

            // Solid white block.
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .frame(width: w, height: h)

            // Letters laid out across the block.
            letterStack
                .font(.system(size: cellSize * 0.72, weight: .bold))
                .foregroundStyle(Color(red: 0.18, green: 0.45, blue: 0.85))
                .frame(width: w, height: h)
        }
        .frame(width: outerW, height: outerH)
        .position(x: centerX, y: centerY)
    }

    @ViewBuilder
    private var letterStack: some View {
        if event.isHorizontal {
            HStack(spacing: 0) {
                ForEach(Array(event.cells.enumerated()), id: \.offset) { _, cell in
                    Text(cell.letter)
                        .frame(width: cellSize, height: cellSize)
                }
            }
        } else {
            VStack(spacing: 0) {
                ForEach(Array(event.cells.enumerated()), id: \.offset) { _, cell in
                    Text(cell.letter)
                        .frame(width: cellSize, height: cellSize)
                }
            }
        }
    }
}
