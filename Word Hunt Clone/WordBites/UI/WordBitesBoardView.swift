import SwiftUI

struct WordBitesBoardView: View {
    @ObservedObject var game: WordBitesModel
    let cellSize: CGFloat

    private var boardWidth: CGFloat { CGFloat(game.cols) * cellSize }
    private var boardHeight: CGFloat { CGFloat(game.rows) * cellSize }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Clipped layer: panel bg, grid, drop highlight, blocks, flash.
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(BlueGameColors.boardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

                GridBackgroundView(cellSize: cellSize, lineColor: Color.white.opacity(0.10), tintCells: true)
                    .frame(width: boardWidth, height: boardHeight)

                if let r = game.dragHoverRow, let c = game.dragHoverCol,
                   let dragID = game.draggingBlockID,
                   let block = game.blocks.first(where: { $0.id == dragID }),
                   game.dragValid {
                    dropHighlight(for: block, row: r, col: c)
                }

                ForEach(game.blocks) { block in
                    WordBitesBlockView(game: game, block: block, cellSize: cellSize)
                }

                WordBitesFlashLayer(game: game, cellSize: cellSize)
                    .frame(width: boardWidth, height: boardHeight)
                    .allowsHitTesting(false)
            }
            .frame(width: boardWidth, height: boardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Toasts drawn above the clip so they can rise outside the board.
            WordBitesToastLayer(game: game, cellSize: cellSize)
                .frame(width: boardWidth, height: boardHeight, alignment: .topLeading)
                .allowsHitTesting(false)
        }
        .frame(width: boardWidth, height: boardHeight)
    }

    private func dropHighlight(for block: WBBlockState, row: Int, col: Int) -> some View {
        let w: CGFloat = block.shape == .horizontal ? cellSize * 2 : cellSize
        let h: CGFloat = block.shape == .vertical ? cellSize * 2 : cellSize
        // Light up the full grid cell(s) rather than draw a rounded inset rect.
        return Rectangle()
            .fill(Color.white.opacity(0.16))
            .frame(width: w, height: h)
            .position(
                x: CGFloat(col) * cellSize + w / 2,
                y: CGFloat(row) * cellSize + h / 2
            )
    }
}
