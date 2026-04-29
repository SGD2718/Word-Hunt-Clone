import Foundation
import Combine
import SwiftUI
import UIKit

final class WordGameModel: ObservableObject {
    enum LiveStatus: Equatable {
        case empty
        case invalid
        case duplicate
        case acceptedNew
    }

    enum RoundState: Equatable {
        case preRound
        case active
        case ended
    }

    struct WordToast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let status: LiveStatus
        let score: Int
    }

    let roundLength = 80

    private let engine: WHWordHuntEngine
    private let pressFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let releaseFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private var roundEndsAt = Date()
    private var lastHapticStatus: LiveStatus = .empty

    @Published private(set) var board: [String] = Array(repeating: "A", count: 16)
    @Published private(set) var seed: UInt64 = 0
    @Published private(set) var score = 0
    @Published private(set) var remainingSeconds = 80
    @Published private(set) var foundWords: [String] = []
    @Published private(set) var foundWordSet: Set<String> = []
    @Published private(set) var selectedPath: [Int] = []
    @Published private(set) var solvedWords: [WHWordResult] = []
    @Published private(set) var isSolving = false
    @Published private(set) var isDictionaryLoaded = false
    @Published private(set) var isGeneratingBoard = false
    @Published private(set) var scorePulse = 0
    @Published private(set) var boardPulse = 0
    @Published private(set) var roundState: RoundState = .preRound
    @Published private(set) var releasedToasts: [WordToast] = []
    @Published var showingSolver = false
    @Published var showingAbout = false

    @AppStorage("boardGenerationMode") private var boardModeRaw: String = BoardGenerationMode.good.rawValue
    private var boardMode: BoardGenerationMode {
        BoardGenerationMode(rawValue: boardModeRaw) ?? .good
    }

    private var currentBoardMetrics: WHGoodBoard?
    private var roundStartedAt: Date?
    private var metricsLoggedForRound = false
    // Set of all valid words findable on the current board, populated
    // when board generation finishes. Word validity during play is
    // membership in this set instead of a full-dictionary lookup.
    private var validWordSet: Set<String> = []

    var currentWord: String {
        engine.word(board: board, path: selectedPath.map(NSNumber.init(value:)))
    }

    var liveStatus: LiveStatus {
        if selectedPath.isEmpty { return .empty }
        let word = currentWord
        if word.count < 3 || !validWordSet.contains(word) { return .invalid }
        if foundWordSet.contains(word) { return .duplicate }
        return .acceptedNew
    }

    var dictionaryInfo: WHDictionaryInfo? {
        engine.dictionaryInfo
    }

    init(engine: WHWordHuntEngine = .shared()) {
        self.engine = engine
        pressFeedback.prepare()
        releaseFeedback.prepare()
        softImpact.prepare()
        loadDictionary()
        startNewGame(seed: UInt64(Date().timeIntervalSince1970))
    }

    func loadDictionary() {
        guard !isDictionaryLoaded else { return }
        do {
            try engine.loadBundledDictionary()
            isDictionaryLoaded = true
        } catch {
            print("WordGameModel: dictionary load failed - \(error.localizedDescription)")
        }
    }

    private struct PreparedBoard {
        let seed: UInt64
        let mode: BoardGenerationMode
        let letters: [String]
        let metrics: WHGoodBoard?
        let solved: [WHWordResult]
        let validWords: Set<String>
    }
    private var preparedBoard: PreparedBoard?

    func startNewGame(seed requestedSeed: UInt64? = nil) {
        guard !isGeneratingBoard else { return }
        score = 0
        foundWords = []
        foundWordSet = []
        selectedPath = []
        isSolving = false
        showingSolver = false
        metricsLoggedForRound = false
        remainingSeconds = roundLength
        releasedToasts = []
        roundState = .preRound
        lastHapticStatus = .empty

        // Prefer a pre-generated board from the previous round. Hold the swap
        // until the start overlay finishes its slide-up animation so the
        // board changeover happens behind a fully-covered screen.
        // Discard cached prepared board if mode changed since it was built.
        if let prepared = preparedBoard, prepared.mode != boardMode {
            preparedBoard = nil
        }
        if requestedSeed == nil, let prepared = preparedBoard {
            preparedBoard = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self else { return }
                self.applyPreparedBoard(prepared)
                self.scheduleNextBoard()
            }
            return
        }

        let nextSeed = requestedSeed ?? UInt64(Date().timeIntervalSince1970 * 1000)
        seed = nextSeed
        solvedWords = []
        validWordSet = []
        currentBoardMetrics = nil
        isGeneratingBoard = true

        let engineRef = engine
        let mode = boardMode
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = WordGameModel.buildPreparedBoard(seed: nextSeed, mode: mode, engine: engineRef)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.applyPreparedBoard(prepared)
            }
        }
    }

    private static func buildPreparedBoard(seed: UInt64, mode: BoardGenerationMode, engine: WHWordHuntEngine) -> PreparedBoard {
        let letters: [String]
        let metrics: WHGoodBoard?
        switch mode {
        case .good:
            let result = engine.generateGoodBoard(seed: seed)
            letters = result.letters
            metrics = result
        case .random:
            letters = engine.generateBoard(seed: seed)
            metrics = nil
        }
        let solved = engine.solve(board: letters)
        let validSet = Set(solved.map(\.word))
        return PreparedBoard(seed: seed, mode: mode, letters: letters, metrics: metrics, solved: solved, validWords: validSet)
    }

    private func applyPreparedBoard(_ prepared: PreparedBoard) {
        seed = prepared.seed
        board = prepared.letters
        currentBoardMetrics = prepared.metrics
        solvedWords = prepared.solved
        validWordSet = prepared.validWords
        isGeneratingBoard = false
        boardPulse += 1
    }

    /// Generate the *next* board off the main thread. Called after a round
    /// begins so it's ready instantly when the user taps New Game.
    private func scheduleNextBoard() {
        guard preparedBoard == nil else { return }
        let nextSeed = UInt64(Date().timeIntervalSince1970 * 1000) &+ UInt64.random(in: 1...0xFFFF)
        let engineRef = engine
        let mode = boardMode
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = WordGameModel.buildPreparedBoard(seed: nextSeed, mode: mode, engine: engineRef)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.preparedBoard = prepared
            }
        }
    }

    func beginRound() {
        guard roundState == .preRound, !isGeneratingBoard else { return }
        roundState = .active
        let now = Date()
        roundEndsAt = now.addingTimeInterval(TimeInterval(roundLength))
        roundStartedAt = now
        remainingSeconds = roundLength
        // Pre-generate the next board so New Game is instant when this round ends.
        scheduleNextBoard()
    }

    func tick() {
        refreshClock()
    }

    func refreshClock(now: Date = Date()) {
        guard roundState == .active else { return }
        let nextRemaining = max(0, Int(ceil(roundEndsAt.timeIntervalSince(now))))
        guard nextRemaining != remainingSeconds else { return }

        remainingSeconds = nextRemaining
        if nextRemaining == 0 {
            roundState = .ended
            revealSolver()
        }
    }

    func selectTile(_ index: Int) {
        refreshClock()
        guard roundState == .active, board.indices.contains(index) else { return }

        if selectedPath.isEmpty {
            selectedPath = [index]
        } else if selectedPath.last == index {
            return
        } else if selectedPath.contains(index) {
            return
        } else if let previous = selectedPath.last, isAdjacent(previous, index) {
            selectedPath.append(index)
        } else {
            return
        }

        let status = liveStatus
        if status == .acceptedNew && lastHapticStatus != .acceptedNew {
            pressFeedback.impactOccurred(intensity: 1.0)
            pressFeedback.prepare()
        }
        lastHapticStatus = status
    }

    func submitSelection() {
        let path = selectedPath.map(NSNumber.init(value:))
        let word = engine.word(board: board, path: path)
        let isPathValid = !selectedPath.isEmpty && !word.isEmpty &&
            engine.isValidPath(board: board, path: path)

        defer {
            selectedPath = []
            lastHapticStatus = .empty
        }
        guard roundState == .active, isPathValid else { return }

        if word.count >= 3, validWordSet.contains(word) {
            if foundWordSet.contains(word) {
                spawnToast(text: word, status: .duplicate, score: 0)
            } else {
                let points = engine.score(word: word)
                score += points
                foundWords.insert(word, at: 0)
                foundWordSet.insert(word)
                scorePulse += 1
                spawnToast(text: word, status: .acceptedNew, score: points)
                releaseFeedback.impactOccurred(intensity: 1.0)
                releaseFeedback.prepare()
            }
        } else {
            spawnToast(text: word, status: .invalid, score: 0)
        }
    }

    private func spawnToast(text: String, status: LiveStatus, score: Int) {
        let toast = WordToast(text: text, status: status, score: score)
        releasedToasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            self?.releasedToasts.removeAll { $0.id == toast.id }
        }
    }

    func revealSolver() {
        guard !isSolving else { return }
        isSolving = true
        if solvedWords.isEmpty {
            solvedWords = engine.solve(board: board)
        }
        isSolving = false
        roundState = .ended
        softImpact.impactOccurred(intensity: 0.9)
        logRoundMetrics()
    }

    private func logRoundMetrics() {
        guard !metricsLoggedForRound, let metrics = currentBoardMetrics else { return }
        metricsLoggedForRound = true

        let longest = foundWords.map(\.count).max() ?? 0
        let duration: Int = {
            guard let started = roundStartedAt else { return roundLength }
            return Int(Date().timeIntervalSince(started).rounded())
        }()

        let row = BoardRoundMetrics(
            seed: seed,
            board: board.joined(),
            heuristicScore: metrics.heuristicScore,
            candidatesEvaluated: Int(metrics.candidatesEvaluated),
            hillClimbAccepted: Int(metrics.hillClimbAccepted),
            solverWordCount: metrics.solverWordCount,
            playerScore: score,
            playerWordCount: foundWords.count,
            playerLongestWord: longest,
            roundDurationSec: duration,
            timestamp: Date()
        )
        BoardMetricsLogger.shared.append(row)
    }

    func forceEndRound() {
        remainingSeconds = 0
        roundState = .ended
        revealSolver()
    }

    func isSelected(_ index: Int) -> Bool {
        selectedPath.contains(index)
    }

    private func isAdjacent(_ lhs: Int, _ rhs: Int) -> Bool {
        let leftRow = lhs / 4
        let leftColumn = lhs % 4
        let rightRow = rhs / 4
        let rightColumn = rhs % 4
        return abs(leftRow - rightRow) <= 1 && abs(leftColumn - rightColumn) <= 1
    }
}
