import Foundation
import Combine
import UIKit

final class WordGameModel: ObservableObject {
    enum SubmissionState: Equatable {
        case idle
        case accepted(String, Int)
        case duplicate(String)
        case invalid(String)
        case loadingFailed(String)

        var message: String {
            switch self {
            case .idle:
                return ""
            case let .accepted(word, score):
                return "+\(score) \(word)"
            case let .duplicate(word):
                return "\(word) already found"
            case let .invalid(word):
                return word.isEmpty ? "No word" : "\(word) not in list"
            case let .loadingFailed(message):
                return message
            }
        }
    }

    let roundLength = 80

    private let engine: WHWordHuntEngine
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private var roundEndsAt = Date()
    @Published private(set) var board: [String] = Array(repeating: "A", count: 16)
    @Published private(set) var seed: UInt64 = 0
    @Published private(set) var score = 0
    @Published private(set) var remainingSeconds = 80
    @Published private(set) var foundWords: [String] = []
    @Published private(set) var foundWordSet: Set<String> = []
    @Published private(set) var selectedPath: [Int] = []
    @Published private(set) var submissionState: SubmissionState = .idle
    @Published private(set) var solvedWords: [WHWordResult] = []
    @Published private(set) var isSolving = false
    @Published private(set) var isDictionaryLoaded = false
    @Published private(set) var scorePulse = 0
    @Published private(set) var boardPulse = 0
    @Published var showingSolver = false
    @Published var showingAbout = false

    var isRoundOver: Bool {
        remainingSeconds <= 0
    }

    var currentWord: String {
        engine.word(board: board, path: selectedPath.map(NSNumber.init(value:)))
    }

    var dictionaryInfo: WHDictionaryInfo? {
        engine.dictionaryInfo
    }

    init(engine: WHWordHuntEngine = .shared()) {
        self.engine = engine
        selectionFeedback.prepare()
        softImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        loadDictionary()
        startNewGame(seed: UInt64(Date().timeIntervalSince1970))
    }

    func loadDictionary() {
        guard !isDictionaryLoaded else { return }
        do {
            try engine.loadBundledDictionary()
            isDictionaryLoaded = true
        } catch {
            submissionState = .loadingFailed(error.localizedDescription)
        }
    }

    func startNewGame(seed requestedSeed: UInt64? = nil) {
        let nextSeed = requestedSeed ?? UInt64(Date().timeIntervalSince1970 * 1000)
        seed = nextSeed
        roundEndsAt = Date().addingTimeInterval(TimeInterval(roundLength))
        board = engine.generateBoard(seed: nextSeed)
        score = 0
        remainingSeconds = roundLength
        foundWords = []
        foundWordSet = []
        selectedPath = []
        solvedWords = []
        isSolving = false
        showingSolver = false
        submissionState = isDictionaryLoaded ? .idle : submissionState
        boardPulse += 1
        rigidImpact.impactOccurred(intensity: 0.7)
    }

    func tick() {
        refreshClock()
    }

    func refreshClock(now: Date = Date()) {
        let nextRemaining = max(0, Int(ceil(roundEndsAt.timeIntervalSince(now))))
        guard nextRemaining != remainingSeconds else { return }

        remainingSeconds = nextRemaining
        if nextRemaining == 0 {
            revealSolver()
        }
    }

    func clearSelection() {
        selectedPath = []
    }

    func selectTile(_ index: Int) {
        refreshClock()
        guard !isRoundOver, board.indices.contains(index) else { return }

        if selectedPath.isEmpty {
            selectedPath = [index]
            selectionFeedback.selectionChanged()
            return
        }

        if selectedPath.last == index {
            return
        }

        if selectedPath.count >= 2, selectedPath[selectedPath.count - 2] == index {
            selectedPath.removeLast()
            selectionFeedback.selectionChanged()
            return
        }

        guard !selectedPath.contains(index), let previous = selectedPath.last, isAdjacent(previous, index) else {
            return
        }
        selectedPath.append(index)
        selectionFeedback.selectionChanged()
    }

    func submitSelection() {
        defer { selectedPath = [] }
        guard !isRoundOver else { return }
        guard !selectedPath.isEmpty else {
            submissionState = .idle
            return
        }

        let path = selectedPath.map(NSNumber.init(value:))
        let word = engine.word(board: board, path: path)
        guard !word.isEmpty else {
            submissionState = .idle
            return
        }

        guard word.count >= 3, engine.isValidPath(board: board, path: path), engine.contains(word: word) else {
            submissionState = .invalid(word)
            return
        }

        guard !foundWordSet.contains(word) else {
            submissionState = .duplicate(word)
            return
        }

        let points = engine.score(word: word)
        score += points
        foundWords.insert(word, at: 0)
        foundWordSet.insert(word)
        submissionState = .accepted(word, points)
        scorePulse += 1
        heavyImpact.impactOccurred(intensity: 1.0)
        heavyImpact.prepare()
    }

    func revealSolver() {
        guard !isSolving else { return }
        isSolving = true
        solvedWords = engine.solve(board: board)
        isSolving = false
        showingSolver = true
        softImpact.impactOccurred(intensity: 0.9)
    }

    func forceEndRound() {
        remainingSeconds = 0
        revealSolver()
    }

    func isSelected(_ index: Int) -> Bool {
        selectedPath.contains(index)
    }

    func selectionNumber(for index: Int) -> Int? {
        selectedPath.firstIndex(of: index).map { $0 + 1 }
    }

    private func isAdjacent(_ lhs: Int, _ rhs: Int) -> Bool {
        let leftRow = lhs / 4
        let leftColumn = lhs % 4
        let rightRow = rhs / 4
        let rightColumn = rhs % 4
        return abs(leftRow - rightRow) <= 1 && abs(leftColumn - rightColumn) <= 1
    }
}
