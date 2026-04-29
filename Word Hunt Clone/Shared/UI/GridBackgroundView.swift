import SwiftUI

struct GridBackgroundView: View {
    let cellSize: CGFloat
    var lineColor: Color = BlueGameColors.gridLine
    var lineWidth: CGFloat = 1
    var tintCells: Bool = false

    var body: some View {
        Canvas { context, size in
            if tintCells {
                let cols = Int(ceil(size.width / cellSize))
                let rows = Int(ceil(size.height / cellSize))
                for r in 0..<rows {
                    for c in 0..<cols {
                        let parity = (r &+ c) & 1
                        let alpha: Double = parity == 0 ? 0.0 : 0.06
                        if alpha == 0 { continue }
                        let rect = CGRect(
                            x: CGFloat(c) * cellSize,
                            y: CGFloat(r) * cellSize,
                            width: cellSize,
                            height: cellSize
                        )
                        context.fill(
                            Path(rect),
                            with: .color(Color.black.opacity(alpha))
                        )
                    }
                }
            }

            var path = Path()
            var x: CGFloat = 0
            while x <= size.width + 0.5 {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += cellSize
            }
            var y: CGFloat = 0
            while y <= size.height + 0.5 {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += cellSize
            }
            context.stroke(
                path,
                with: .color(lineColor),
                style: StrokeStyle(lineWidth: lineWidth, dash: [3, 4])
            )
        }
        .allowsHitTesting(false)
    }
}
