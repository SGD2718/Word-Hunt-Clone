import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var game: WordGameModel
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                GameColors.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    GameTitleBar()

                    ScoreStrip(game: game)
                        .padding(.horizontal, 12)
                    
                    CurrentWordView(word: game.currentWord, state: game.submissionState)
                        .padding(.top, 2)
                    
                    WordBoardView(game: game)
                        .frame(maxWidth: 360)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .scaleEffect(game.boardPulse == 0 ? 1 : 1.01)
                        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: game.boardPulse)

                    FoundWordsView(words: game.foundWords)
                        .padding(.horizontal, 12)

                    ControlBar(game: game)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
                }
                .padding(.top, 10)
                .padding(.horizontal, 8)
                .frame(maxWidth: 520)
            }
            .toolbar(.hidden, for: .navigationBar)
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.15)) {
                    game.tick()
                }
            }
            .sheet(isPresented: $game.showingSolver) {
                SolverReviewView(game: game)
            }
            .sheet(isPresented: $game.showingAbout) {
                AboutView(info: game.dictionaryInfo, seed: game.seed)
            }
        }
    }
}

private enum GameColors {
    static let deepBlue = Color(red: 0.03, green: 0.28, blue: 0.13)
    static let blue = Color(red: 0.08, green: 0.55, blue: 0.24)
    static let lightBlue = Color(red: 0.42, green: 0.78, blue: 0.28)
    static let tile = Color(red: 0.97, green: 0.88, blue: 0.60)
    static let tileEdge = Color(red: 0.70, green: 0.47, blue: 0.18)
    static let selected = Color(red: 0.98, green: 0.61, blue: 0.10)
    static let selectedEdge = Color(red: 0.76, green: 0.30, blue: 0.05)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [lightBlue, blue, deepBlue],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct GameTitleBar: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 10, height: 10)
            Text("WORD HUNT")
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

private struct ScoreStrip: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        HStack(spacing: 8) {
            ScorePill(title: "TIME", value: timeText, tone: game.remainingSeconds <= 10 ? .red : .white)
            ScorePill(title: "SCORE", value: "\(game.score)", tone: .white)
                .scaleEffect(scoreScale)
                .animation(.spring(response: 0.2, dampingFraction: 0.45), value: game.scorePulse)
            ScorePill(title: "WORDS", value: "\(game.foundWords.count)", tone: .white)
        }
    }

    private var timeText: String {
        let minutes = game.remainingSeconds / 60
        let seconds = game.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var scoreScale: CGFloat {
        game.scorePulse.isMultiple(of: 2) ? 1 : 1.07
    }
}

private struct ScorePill: View {
    let title: String
    let value: String
    let tone: Color

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.02, green: 0.24, blue: 0.12).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct CurrentWordView: View {
    let word: String
    let state: WordGameModel.SubmissionState

    var body: some View {
        ZStack {
            Capsule()
                .fill(Color(red: 0.02, green: 0.21, blue: 0.10).opacity(0.78))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))

            HStack(spacing: 10) {
                Text(displayWord)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .id(displayWord)
                    .transition(.scale.combined(with: .opacity))

                if showsMessage {
                    Text(state.message)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(stateColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .animation(.spring(response: 0.24, dampingFraction: 0.68), value: word)
        .animation(.spring(response: 0.2, dampingFraction: 0.72), value: state.message)
    }

    private var displayWord: String {
        if !word.isEmpty {
            return word
        }
        switch state {
        case .accepted:
            return "NICE"
        case .duplicate:
            return "DUPLICATE"
        case .invalid:
            return "NOPE"
        case .loadingFailed:
            return "ERROR"
        case .idle:
            return "READY"
        }
    }

    private var showsMessage: Bool {
        !state.message.isEmpty
    }

    private var stateColor: Color {
        switch state {
        case .accepted:
            return Color(red: 0.64, green: 1.0, blue: 0.58)
        case .duplicate:
            return Color(red: 1.0, green: 0.86, blue: 0.28)
        case .invalid, .loadingFailed:
            return Color(red: 1.0, green: 0.45, blue: 0.38)
        case .idle:
            return .white.opacity(0.68)
        }
    }
}

private struct WordBoardView: View {
    @ObservedObject var game: WordGameModel
    @State private var lastDragLocation: CGPoint?
    private let spacing: CGFloat = 7

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let length = tileLength(in: size)

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.10, green: 0.58, blue: 0.26), Color(red: 0.03, green: 0.32, blue: 0.16)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.28), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 7)

                ForEach(0..<16, id: \.self) { index in
                    TileView(
                        letter: game.board[index],
                        isSelected: game.isSelected(index),
                        order: game.selectionNumber(for: index)
                    )
                    .frame(width: length, height: length)
                    .position(tileCenter(for: index, in: size))
                    .accessibilityIdentifier("tile-\(index)")
                    .animation(.spring(response: 0.18, dampingFraction: 0.62), value: game.isSelected(index))
                }

                SelectionPathView(path: game.selectedPath.map { tileCenter(for: $0, in: size) }, lineWidth: length * 0.17)
                    .allowsHitTesting(false)
            }
            .padding(4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChange(to: value.location, in: size)
                    }
                    .onEnded { _ in
                        lastDragLocation = nil
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                            game.submitSelection()
                        }
                    }
            )
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

        for index in 0..<16 {
            let center = tileCenter(for: index, in: size)
            let dx = point.x - center.x
            let dy = point.y - center.y
            let useCircle: Bool = {
                guard let current else { return false }
                if index == current { return false }
                if pathSet.contains(index) { return true }
                return isOrthogonal(index, current)
            }()
            if useCircle {
                let dist2 = dx * dx + dy * dy
                if dist2 <= half * half {
                    candidates.append((index, sqrt(dist2) / half))
                }
            } else {
                let ax = abs(dx)
                let ay = abs(dy)
                if ax <= half && ay <= half {
                    candidates.append((index, max(ax, ay) / half))
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

private struct SelectionPathView: View {
    let path: [CGPoint]
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
                with: .color(Color.white.opacity(0.88)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )
            context.stroke(
                shape,
                with: .color(GameColors.selected.opacity(0.95)),
                style: StrokeStyle(lineWidth: max(3, lineWidth * 0.46), lineCap: .round, lineJoin: .round)
            )
        }
        .animation(.spring(response: 0.18, dampingFraction: 0.7), value: path.count)
    }
}

private struct TileView: View {
    let letter: String
    let isSelected: Bool
    let order: Int?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    LinearGradient(
                        colors: isSelected
                            ? [Color(red: 1.0, green: 0.78, blue: 0.24), GameColors.selected]
                            : [Color(red: 1.0, green: 0.94, blue: 0.70), GameColors.tile],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isSelected ? GameColors.selectedEdge : GameColors.tileEdge, lineWidth: 3)
                )
                .shadow(color: .black.opacity(isSelected ? 0.35 : 0.25), radius: isSelected ? 6 : 3, x: 0, y: isSelected ? 4 : 2)

            Text(letter)
                .font(.system(size: 48, weight: .black, design: .rounded))
                .foregroundStyle(GameColors.ink)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -1)
                .shadow(color: .white.opacity(0.45), radius: 0, x: 0, y: 1)
        }
        .overlay(alignment: .topTrailing) {
            if let order {
                Text("\(order)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 21, height: 21)
                    .background(GameColors.deepBlue.opacity(0.8), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 1))
                    .padding(5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isSelected ? 1.08 : 1)
        .rotationEffect(.degrees(isSelected ? -1.4 : 0))
    }
}

private struct FoundWordsView: View {
    let words: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("FOUND")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
            }

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(words, id: \.self) { word in
                        Text(word)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(GameColors.ink)
                            .background(GameColors.tile.opacity(0.96), in: RoundedRectangle(cornerRadius: 7))
                            .overlay(RoundedRectangle(cornerRadius: 7).stroke(GameColors.tileEdge.opacity(0.8), lineWidth: 1.5))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: words)
            }
        }
        .frame(maxHeight: 145)
    }
}

private struct ControlBar: View {
    @ObservedObject var game: WordGameModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    game.startNewGame()
                }
            } label: {
                Label("New Game", systemImage: "arrow.clockwise")
            }
            .buttonStyle(GameButtonStyle())

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    game.forceEndRound()
                }
            } label: {
                Label("Reveal", systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(GameButtonStyle())
            .disabled(game.isSolving)

            Button {
                game.showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
            .buttonStyle(GameButtonStyle(compact: true))
        }
    }
}

private struct GameButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, 10)
            .frame(maxWidth: compact ? 92 : .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(red: 0.02, green: 0.24, blue: 0.12).opacity(configuration.isPressed ? 0.72 : 0.92))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.22), lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(game: WordGameModel())
    }
}
