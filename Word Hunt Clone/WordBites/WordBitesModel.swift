import Foundation
import Combine
import SwiftUI
import UIKit

final class WordBitesModel: ObservableObject {
    enum RoundState: Equatable {
        case preRound
        case active
        case ended
    }

    struct WordToast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let score: Int
        let row: Int
        let col: Int
        let length: Int
        let isHorizontal: Bool
    }

    struct FlashEvent: Identifiable, Equatable {
        let id = UUID()
        let cells: [Cell]
        let isHorizontal: Bool
        let text: String
        let row: Int
        let col: Int
    }

    struct Cell: Hashable {
        let row: Int
        let col: Int
        let letter: String
    }

    let cols: Int = 8
    let rows: Int = 9
    let roundLength: Int = 80

    @Published private(set) var blocks: [WBBlockState] = []
    @Published private(set) var seed: UInt64 = 0
    @Published private(set) var score: Int = 0
    @Published private(set) var remainingSeconds: Int = 80
    @Published private(set) var foundWords: [String] = []
    @Published private(set) var foundWordSet: Set<String> = []
    @Published private(set) var roundState: RoundState = .preRound
    @Published private(set) var releasedToasts: [WordToast] = []
    @Published private(set) var flashEvents: [FlashEvent] = []
    @Published private(set) var isGeneratingBoard: Bool = false
    @Published private(set) var scorePulse: Int = 0
    @Published private(set) var boardPulse: Int = 0
    @Published var draggingBlockID: UUID? = nil
    @Published var dragHoverRow: Int? = nil
    @Published var dragHoverCol: Int? = nil
    @Published var dragValid: Bool = false
    @Published var showingAbout = false
    @Published var showingWords = false
    @Published var showingAllWords = false

    @AppStorage("boardGenerationMode") private var boardModeRaw: String = BoardGenerationMode.good.rawValue
    private var boardMode: BoardGenerationMode {
        BoardGenerationMode(rawValue: boardModeRaw) ?? .good
    }

    private let engine: WBEngine
    private let huntEngine: WHWordHuntEngine
    private let wordHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let endRoundHaptic = UIImpactFeedbackGenerator(style: .soft)
    private var roundEndsAt: Date = Date()

    init(engine: WBEngine = .shared(), huntEngine: WHWordHuntEngine = .shared()) {
        self.engine = engine
        self.huntEngine = huntEngine
        wordHaptic.prepare()
        endRoundHaptic.prepare()
        loadDictionaryIfNeeded()
        startNewGame()
    }

    /// All dictionary words (length ≤ vertical board height) whose letter
    /// multiset is a subset of the dealt letters. Used by the end-of-round
    /// "all words" review.
    func allFormableWords() -> [String] {
        var letters = ""
        for b in blocks {
            letters.append(b.letterA)
            if !b.letterB.isEmpty { letters.append(b.letterB) }
        }
        return huntEngine.wordsFormable(fromLetters: letters, maxLength: rows)
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                return lhs < rhs
            }
    }

    private func loadDictionaryIfNeeded() {
        if !huntEngine.isLoaded {
            try? huntEngine.loadBundledDictionary()
        }
    }

    private struct PreparedDeal {
        let seed: UInt64
        let mode: BoardGenerationMode
        let blocks: [WBBlockState]
        let preExistingWords: Set<String>
    }
    private var preparedDeal: PreparedDeal?

    func startNewGame(seed requestedSeed: UInt64? = nil) {
        guard !isGeneratingBoard else { return }
        score = 0
        foundWords = []
        foundWordSet = []
        releasedToasts = []
        flashEvents = []
        roundState = .preRound
        remainingSeconds = roundLength

        // Use a pre-generated deal if one's ready. Defer the swap until the
        // start overlay finishes sliding up so the board changeover happens
        // behind a fully-covered screen.
        // Discard cached deal if mode changed since it was built.
        if let prepared = preparedDeal, prepared.mode != boardMode {
            preparedDeal = nil
        }
        if requestedSeed == nil, let prepared = preparedDeal {
            preparedDeal = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.applyPrepared(prepared)
                self.scheduleNextDeal()
            }
            return
        }

        let nextSeed = requestedSeed ?? UInt64(Date().timeIntervalSince1970 * 1000)
        isGeneratingBoard = true
        let engineRef = engine
        let mode = boardMode
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = WordBitesModel.buildPreparedDeal(
                seed: nextSeed,
                mode: mode,
                engine: engineRef,
                cols: 8
            )
            DispatchQueue.main.async { [weak self] in
                self?.applyPrepared(prepared)
            }
        }
    }

    private func applyPrepared(_ prepared: PreparedDeal) {
        seed = prepared.seed
        blocks = prepared.blocks
        foundWordSet = prepared.preExistingWords
        isGeneratingBoard = false
        boardPulse += 1
    }

    private static func buildPreparedDeal(seed: UInt64, mode: BoardGenerationMode, engine: WBEngine, cols: Int) -> PreparedDeal {
        let dealt: [WBBlockInfo]
        switch mode {
        case .good: dealt = engine.dealGoodBlocks(seed: seed)
        case .random: dealt = engine.dealBlocks(seed: seed)
        }
        let blocks: [WBBlockState] = dealt.map { info in
            WBBlockState(
                shape: info.shape,
                letterA: info.letterA,
                letterB: info.letterB,
                row: info.row,
                col: info.col
            )
        }
        // Build the flat grid string from these blocks for the initial scan.
        var chars = [Character](repeating: " ", count: cols * 9)
        for b in blocks {
            for (i, cell) in b.cellsOccupied().enumerated() {
                let letter = (i == 0 ? b.letterA : b.letterB).first ?? " "
                let idx = cell.row * cols + cell.col
                if idx >= 0 && idx < chars.count { chars[idx] = letter }
            }
        }
        let grid = String(chars)
        let preExisting = Set(engine.findWords(grid: grid).map { $0.word })
        return PreparedDeal(seed: seed, mode: mode, blocks: blocks, preExistingWords: preExisting)
    }

    /// Generate the *next* deal off the main thread so New Game is instant.
    private func scheduleNextDeal() {
        guard preparedDeal == nil else { return }
        let nextSeed = UInt64(Date().timeIntervalSince1970 * 1000) &+ UInt64.random(in: 1...0xFFFF)
        let engineRef = engine
        let colsRef = cols
        let mode = boardMode
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = WordBitesModel.buildPreparedDeal(seed: nextSeed, mode: mode, engine: engineRef, cols: colsRef)
            DispatchQueue.main.async { [weak self] in
                self?.preparedDeal = prepared
            }
        }
    }

    func beginRound() {
        guard roundState == .preRound, !isGeneratingBoard else { return }
        roundState = .active
        roundEndsAt = Date().addingTimeInterval(TimeInterval(roundLength))
        remainingSeconds = roundLength
        // Pre-generate the next deal so New Game is instant after this round.
        scheduleNextDeal()
    }

    func tick() { refreshClock() }

    func refreshClock(now: Date = Date()) {
        guard roundState == .active else { return }
        let next = max(0, Int(ceil(roundEndsAt.timeIntervalSince(now))))
        guard next != remainingSeconds else { return }
        remainingSeconds = next
        if next == 0 {
            endRound()
        }
    }

    func endRound() {
        guard roundState != .ended else { return }
        remainingSeconds = 0
        roundState = .ended
        endRoundHaptic.impactOccurred(intensity: 0.9)
    }

    // MARK: - Drag

    func beginDrag(blockID: UUID) {
        guard roundState == .active else { return }
        draggingBlockID = blockID
        dragHoverRow = nil
        dragHoverCol = nil
        dragValid = false
    }

    func updateDragHover(blockID: UUID, anchorRow: Int?, anchorCol: Int?) {
        guard draggingBlockID == blockID else { return }
        dragHoverRow = anchorRow
        dragHoverCol = anchorCol
        if let r = anchorRow, let c = anchorCol {
            dragValid = canPlace(blockID: blockID, anchorRow: r, anchorCol: c)
        } else {
            dragValid = false
        }
    }

    @discardableResult
    func commitDrop(blockID: UUID, anchorRow: Int?, anchorCol: Int?) -> Bool {
        defer {
            draggingBlockID = nil
            dragHoverRow = nil
            dragHoverCol = nil
            dragValid = false
        }
        guard roundState == .active else { return false }
        guard let idx = blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        guard let r = anchorRow, let c = anchorCol,
              canPlace(blockID: blockID, anchorRow: r, anchorCol: c) else {
            return false
        }
        blocks[idx].row = r
        blocks[idx].col = c
        evaluateAfterMove(movedBlock: blocks[idx])
        return true
    }

    func canPlace(blockID: UUID, anchorRow: Int, anchorCol: Int) -> Bool {
        guard let block = blocks.first(where: { $0.id == blockID }) else { return false }
        var r2 = anchorRow
        var c2 = anchorCol
        switch block.shape {
        case .horizontal: c2 = anchorCol + 1
        case .vertical: r2 = anchorRow + 1
        default: break
        }
        if anchorRow < 0 || anchorCol < 0 || r2 >= rows || c2 >= cols { return false }
        for other in blocks where other.id != blockID {
            for cell in other.cellsOccupied() {
                if (cell.row == anchorRow && cell.col == anchorCol) ||
                   (cell.row == r2 && cell.col == c2) {
                    return false
                }
            }
        }
        return true
    }

    // MARK: - Word evaluation

    private func buildGridString() -> String {
        var chars = [Character](repeating: " ", count: cols * rows)
        for b in blocks {
            for (i, cell) in b.cellsOccupied().enumerated() {
                let letter = (i == 0 ? b.letterA : b.letterB).first ?? " "
                let idx = cell.row * cols + cell.col
                if idx >= 0 && idx < chars.count { chars[idx] = letter }
            }
        }
        return String(chars)
    }

    private func evaluateAfterMove(movedBlock: WBBlockState) {
        let grid = buildGridString()
        // Full grid scan — the board is 8x9 so this is microseconds, and it
        // sidesteps any edge case in the per-axis incremental scan where a
        // word formed at the seam between two blocks could be missed.
        let hits = engine.findWords(grid: grid)
        for hit in hits {
            let word = hit.word
            guard !foundWordSet.contains(word) else { continue }
            let points = hit.score
            let isHorizontal = (hit.orientations & 1) != 0
            score += points
            foundWords.insert(word, at: 0)
            foundWordSet.insert(word)
            scorePulse += 1
            wordHaptic.impactOccurred(intensity: 1.0)
            wordHaptic.prepare()
            spawnToast(
                text: word,
                score: points,
                row: hit.row,
                col: hit.col,
                length: hit.length,
                isHorizontal: isHorizontal
            )
            flashCells(forHit: hit, isHorizontal: isHorizontal)
        }
    }

    private func spawnToast(text: String, score: Int, row: Int, col: Int, length: Int, isHorizontal: Bool) {
        let toast = WordToast(
            text: text,
            score: score,
            row: row,
            col: col,
            length: length,
            isHorizontal: isHorizontal
        )
        releasedToasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.05) { [weak self] in
            self?.releasedToasts.removeAll { $0.id == toast.id }
        }
    }

    private func flashCells(forHit hit: WBWordHit, isHorizontal: Bool) {
        var cells: [Cell] = []
        let chars = Array(hit.word)
        for i in 0..<hit.length {
            let r = isHorizontal ? hit.row : hit.row + i
            let c = isHorizontal ? hit.col + i : hit.col
            let letter = i < chars.count ? String(chars[i]) : ""
            cells.append(Cell(row: r, col: c, letter: letter))
        }
        let event = FlashEvent(
            cells: cells,
            isHorizontal: isHorizontal,
            text: hit.word,
            row: hit.row,
            col: hit.col
        )
        flashEvents.append(event)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) { [weak self] in
            self?.flashEvents.removeAll { $0.id == event.id }
        }
    }
}
