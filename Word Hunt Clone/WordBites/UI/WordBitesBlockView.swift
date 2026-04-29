import SwiftUI

struct WordBitesBlockView: View {
    @ObservedObject var game: WordBitesModel
    let block: WBBlockState
    let cellSize: CGFloat

    @State private var translation: CGSize = .zero
    @State private var dragging: Bool = false
    @State private var redOpacity: Double = 0
    @State private var lastValidRow: Int = -1
    @State private var lastValidCol: Int = -1

    private var width: CGFloat {
        switch block.shape {
        case .horizontal: return cellSize * 2
        case .vertical: return cellSize
        default: return cellSize
        }
    }

    private var height: CGFloat {
        switch block.shape {
        case .vertical: return cellSize * 2
        case .horizontal: return cellSize
        default: return cellSize
        }
    }

    private var centerX: CGFloat { CGFloat(block.col) * cellSize + width / 2 }
    private var centerY: CGFloat { CGFloat(block.row) * cellSize + height / 2 }

    var body: some View {
        let inset: CGFloat = 4
        let w = width - inset
        let h = height - inset

        ZStack {
            // Red invalid radial — drawn behind the tile so it bleeds outward
            // beyond the block's footprint. Generous frame to allow spread.
            invalidGlow
                .frame(width: width * 2.4, height: height * 2.4)
                .opacity(redOpacity)
                .allowsHitTesting(false)

            // 3D effect: dark "shadow" rect underneath, slightly lower.
            // Tints red along with the tile face on invalid drag.
            RoundedRectangle(cornerRadius: 8)
                .fill(BlueGameColors.woodShadow)
                .frame(width: w, height: h)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BlueGameColors.dragInvalidRed)
                        .opacity(redOpacity)
                )
                .offset(y: 3)

            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    colors: [BlueGameColors.woodHighlight, BlueGameColors.wood],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: w, height: h)
                .overlay(blockLetters)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(BlueGameColors.dragInvalidTint)
                        .frame(width: w, height: h)
                        .opacity(redOpacity)
                        .allowsHitTesting(false)
                )
        }
        .frame(width: width, height: height)
        .position(x: centerX, y: centerY)
        .offset(x: translation.width, y: translation.height)
        .zIndex(dragging ? 100 : 0)
        .gesture(dragGesture)
        .onChange(of: game.dragValid) { _, _ in
            updateRedOpacity()
        }
        .onChange(of: game.draggingBlockID) { _, newValue in
            if newValue != block.id {
                redOpacity = 0
            }
        }
    }

    @ViewBuilder
    private var blockLetters: some View {
        let textColor = BlueGameColors.ink
        switch block.shape {
        case .single:
            Text(block.letterA)
                .font(.system(size: cellSize * 0.72, weight: .bold))
                .foregroundStyle(textColor)
        case .horizontal:
            HStack(spacing: 0) {
                Text(block.letterA)
                    .frame(width: cellSize, height: cellSize)
                Text(block.letterB)
                    .frame(width: cellSize, height: cellSize)
            }
            .font(.system(size: cellSize * 0.72, weight: .bold))
            .foregroundStyle(textColor)
        case .vertical:
            VStack(spacing: 0) {
                Text(block.letterA)
                    .frame(width: cellSize, height: cellSize)
                Text(block.letterB)
                    .frame(width: cellSize, height: cellSize)
            }
            .font(.system(size: cellSize * 0.72, weight: .bold))
            .foregroundStyle(textColor)
        @unknown default:
            EmptyView()
        }
    }

    private var invalidGlow: some View {
        // Soft radial glow — circle for single, stretched ellipse for pairs.
        // Drawn unclipped so it bleeds beyond the tile.
        let scaleX: CGFloat = block.shape == .horizontal ? 1.6 : 1
        let scaleY: CGFloat = block.shape == .vertical ? 1.6 : 1
        return Circle()
            .fill(
                RadialGradient(
                    colors: [BlueGameColors.dragInvalidRed, .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: cellSize * 1.0
                )
            )
            .scaleEffect(x: scaleX, y: scaleY)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard game.roundState == .active else { return }
                if !dragging {
                    dragging = true
                    lastValidRow = block.row
                    lastValidCol = block.col
                    game.beginDrag(blockID: block.id)
                }
                translation = value.translation
                let dr = (value.translation.height / cellSize).rounded()
                let dc = (value.translation.width / cellSize).rounded()
                let r = block.row + Int(dr)
                let c = block.col + Int(dc)
                let withinBoard = r >= 0 && c >= 0 && r < game.rows && c < game.cols
                game.updateDragHover(
                    blockID: block.id,
                    anchorRow: withinBoard ? r : nil,
                    anchorCol: withinBoard ? c : nil
                )
                if withinBoard && game.canPlace(blockID: block.id, anchorRow: r, anchorCol: c) {
                    lastValidRow = r
                    lastValidCol = c
                }
            }
            .onEnded { value in
                guard dragging else { return }
                let dr = (value.translation.height / cellSize).rounded()
                let dc = (value.translation.width / cellSize).rounded()
                let r = block.row + Int(dr)
                let c = block.col + Int(dc)

                let oldRow = block.row
                let oldCol = block.col
                var finalRow = oldRow
                var finalCol = oldCol
                if game.commitDrop(blockID: block.id, anchorRow: r, anchorCol: c) {
                    finalRow = r; finalCol = c
                } else if lastValidRow >= 0 && lastValidCol >= 0,
                          game.commitDrop(
                              blockID: block.id,
                              anchorRow: lastValidRow,
                              anchorCol: lastValidCol
                          ) {
                    finalRow = lastValidRow; finalCol = lastValidCol
                }

                // After commit, block.row/col jump to finalRow/finalCol on the
                // next body eval. Pre-shift translation so the visual position
                // stays continuous with where the finger left it, then ease
                // translation to zero — block glides into its new home.
                let dx = CGFloat(oldCol - finalCol) * cellSize + value.translation.width
                let dy = CGFloat(oldRow - finalRow) * cellSize + value.translation.height
                translation = CGSize(width: dx, height: dy)
                withAnimation(.easeOut(duration: 0.09)) {
                    translation = .zero
                }

                dragging = false
                lastValidRow = -1
                lastValidCol = -1
                withAnimation(.easeOut(duration: 0.25)) {
                    redOpacity = 0
                }
            }
    }

    private func updateRedOpacity() {
        let isMe = game.draggingBlockID == block.id
        let target: Double = (isMe && !game.dragValid && game.dragHoverRow != nil) ? 1.0 : 0.0
        withAnimation(.easeOut(duration: 0.25)) {
            redOpacity = target
        }
    }
}

