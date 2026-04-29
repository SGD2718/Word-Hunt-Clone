import SwiftUI

struct WordBoardView: View {
    @ObservedObject var game: WordGameModel
    @State private var lastDragLocation: CGPoint?
    @State private var fadingStroke: FadingStroke?
    @State private var fadingOpacity: Double = 1
    private let spacing: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let length = tileLength(in: size)
            let lineWidth = length * 0.17

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(GameColors.boardInner)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(GameColors.boardBorder, lineWidth: 6)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 5)

                ForEach(0..<16, id: \.self) { index in
                    let isSelected = game.isSelected(index)
                    TileView(
                        letter: game.board[index],
                        fill: isSelected ? game.liveStatus.tileFill : (GameColors.woodHighlight, GameColors.wood)
                    )
                    .frame(width: length, height: length)
                    .position(tileCenter(for: index, in: size))
                    .accessibilityIdentifier("tile-\(index)")
                    .animation(.spring(response: 0.18, dampingFraction: 0.62), value: isSelected)
                    .animation(.easeInOut(duration: 0.12), value: game.liveStatus)
                }

                if let fading = fadingStroke {
                    SelectionPathView(path: fading.points, color: fading.color, lineWidth: fading.lineWidth)
                        .opacity(fadingOpacity)
                        .allowsHitTesting(false)
                }

                SelectionPathView(
                    path: game.selectedPath.map { tileCenter(for: $0, in: size) },
                    color: game.liveStatus.strokeColor,
                    lineWidth: lineWidth
                )
                .allowsHitTesting(false)

                if game.isGeneratingBoard {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.45))
                    VStack(spacing: 10) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("Building board…")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .contentShape(Rectangle())
            .allowsHitTesting(!game.isGeneratingBoard && game.roundState == .active)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(to: value.location, in: size)
                    }
                    .onEnded { _ in
                        lastDragLocation = nil
                        captureFadingStroke(in: size, lineWidth: lineWidth)
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            game.submitSelection()
                        }
                    }
            )
        }
    }

    private func captureFadingStroke(in size: CGSize, lineWidth: CGFloat) {
        let centers = game.selectedPath.map { tileCenter(for: $0, in: size) }
        guard centers.count >= 2 else { return }
        let stroke = FadingStroke(points: centers, color: game.liveStatus.strokeColor, lineWidth: lineWidth)
        fadingStroke = stroke
        fadingOpacity = 1
        withAnimation(.easeOut(duration: 0.4)) {
            fadingOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if fadingStroke?.id == stroke.id {
                fadingStroke = nil
                fadingOpacity = 1
            }
        }
    }

    private func tileLength(in size: CGSize) -> CGFloat {
        let boardLength = min(size.width, size.height) - 22
        return (boardLength - spacing * 3) / 4
    }

    private func boardOrigin(in size: CGSize) -> CGPoint {
        let length = tileLength(in: size)
        let boardLength = length * 4 + spacing * 3
        return CGPoint(
            x: (size.width - boardLength) / 2,
            y: (size.height - boardLength) / 2
        )
    }

    private func tileCenter(for index: Int, in size: CGSize) -> CGPoint {
        let length = tileLength(in: size)
        let origin = boardOrigin(in: size)
        let row = CGFloat(index / 4)
        let column = CGFloat(index % 4)
        return CGPoint(
            x: origin.x + column * (length + spacing) + length / 2,
            y: origin.y + row * (length + spacing) + length / 2
        )
    }

    private func tileIndex(at point: CGPoint, in size: CGSize) -> Int? {
        let length = tileLength(in: size)
        let half = length / 2
        let path = game.selectedPath
        let pathSet = Set(path)
        let current = path.last
        var candidates: [(index: Int, score: CGFloat)] = []

        enum HitShape { case square, circle, rhombus }

        for index in 0..<16 {
            let center = tileCenter(for: index, in: size)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let ax = abs(dx)
            let ay = abs(dy)
            let shape: HitShape = {
                guard let current else { return .square }
                if index == current { return .square }
                if pathSet.contains(index) { return .rhombus }
                if isOrthogonal(index, current) { return .circle }
                return .square
            }()
            switch shape {
            case .square:
                if ax <= half && ay <= half {
                    candidates.append((index, max(ax, ay) / half))
                }
            case .circle:
                let dist2 = dx * dx + dy * dy
                if dist2 <= half * half {
                    candidates.append((index, sqrt(dist2) / half))
                }
            case .rhombus:
                if ax + ay <= half {
                    candidates.append((index, (ax + ay) / half))
                }
            }
        }

        guard !candidates.isEmpty else { return nil }

        if let last = current {
            let lastCenter = tileCenter(for: last, in: size)
            let dragVector = CGPoint(x: point.x - lastCenter.x, y: point.y - lastCenter.y)
            let adjacentUnselected = candidates.filter { candidate in
                candidate.index != last &&
                !pathSet.contains(candidate.index) &&
                isAdjacent(last, candidate.index)
            }

            if let directed = adjacentUnselected.max(by: { lhs, rhs in
                directionalScore(from: last, to: lhs.index, dragVector: dragVector, in: size) <
                    directionalScore(from: last, to: rhs.index, dragVector: dragVector, in: size)
            }) {
                return directed.index
            }
        }

        return candidates.min(by: { $0.score < $1.score })?.index
    }

    private func directionalScore(from start: Int, to destination: Int, dragVector: CGPoint, in size: CGSize) -> CGFloat {
        let startCenter = tileCenter(for: start, in: size)
        let destinationCenter = tileCenter(for: destination, in: size)
        let direction = CGPoint(x: destinationCenter.x - startCenter.x, y: destinationCenter.y - startCenter.y)
        return direction.x * dragVector.x + direction.y * dragVector.y
    }

    private func isAdjacent(_ lhs: Int, _ rhs: Int) -> Bool {
        let leftRow = lhs / 4
        let leftColumn = lhs % 4
        let rightRow = rhs / 4
        let rightColumn = rhs % 4
        return abs(leftRow - rightRow) <= 1 && abs(leftColumn - rightColumn) <= 1
    }

    private func isOrthogonal(_ lhs: Int, _ rhs: Int) -> Bool {
        let leftRow = lhs / 4
        let leftColumn = lhs % 4
        let rightRow = rhs / 4
        let rightColumn = rhs % 4
        return abs(leftRow - rightRow) + abs(leftColumn - rightColumn) == 1
    }

    private func handleDragChange(to location: CGPoint, in size: CGSize) {
        let length = tileLength(in: size)
        let step = length + spacing
        let previous = lastDragLocation ?? location
        let distance = hypot(location.x - previous.x, location.y - previous.y)
        let sampleCount = max(1, Int(ceil(distance / max(6, step * 0.16))))

        for sample in 0...sampleCount {
            let progress = CGFloat(sample) / CGFloat(sampleCount)
            let point = CGPoint(
                x: previous.x + (location.x - previous.x) * progress,
                y: previous.y + (location.y - previous.y) * progress
            )
            if let index = tileIndex(at: point, in: size) {
                withAnimation(.spring(response: 0.16, dampingFraction: 0.74)) {
                    game.selectTile(index)
                }
            }
        }

        lastDragLocation = location
    }
}

private struct FadingStroke: Identifiable, Equatable {
    let id = UUID()
    let points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
}

private struct SelectionPathView: View {
    let path: [CGPoint]
    let color: Color
    let lineWidth: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard path.count > 1 else { return }
            var shape = Path()
            shape.move(to: path[0])
            for point in path.dropFirst() {
                shape.addLine(to: point)
            }
            context.stroke(
                shape,
                with: .color(color.opacity(0.55)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }
}

private struct TileView: View {
    let letter: String
    let fill: (top: Color, bottom: Color)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    LinearGradient(
                        colors: [fill.top, fill.bottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 2)

            Text(letter)
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(GameColors.ink)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -1)
        }
    }
}
