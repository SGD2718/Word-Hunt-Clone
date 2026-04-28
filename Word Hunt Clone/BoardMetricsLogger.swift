import Foundation

struct BoardRoundMetrics {
    let seed: UInt64
    let board: String
    let heuristicScore: Int64
    let candidatesEvaluated: Int
    let hillClimbAccepted: Int
    let solverWordCount: Int
    let playerScore: Int
    let playerWordCount: Int
    let playerLongestWord: Int
    let roundDurationSec: Int
    let timestamp: Date

    func jsonObject() -> [String: Any] {
        let iso = ISO8601DateFormatter()
        return [
            "seed": seed,
            "board": board,
            "heuristicScore": heuristicScore,
            "candidatesEvaluated": candidatesEvaluated,
            "hillClimbAccepted": hillClimbAccepted,
            "solverWordCount": solverWordCount,
            "playerScore": playerScore,
            "playerWordCount": playerWordCount,
            "playerLongestWord": playerLongestWord,
            "roundDurationSec": roundDurationSec,
            "timestamp": iso.string(from: timestamp)
        ]
    }
}

final class BoardMetricsLogger {
    static let shared = BoardMetricsLogger()

    private let queue = DispatchQueue(label: "BoardMetricsLogger")
    private let fileURL: URL?

    init() {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true) else {
            fileURL = nil
            return
        }
        fileURL = dir.appendingPathComponent("board_metrics.jsonl")
    }

    func append(_ metrics: BoardRoundMetrics) {
        guard let fileURL else { return }
        let object = metrics.jsonObject()
        queue.async {
            guard let data = try? JSONSerialization.data(withJSONObject: object,
                                                         options: [.sortedKeys]) else { return }
            var line = data
            line.append(0x0A) // newline
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let handle = try? FileHandle(forWritingTo: fileURL) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: line)
                }
            } else {
                try? line.write(to: fileURL)
            }
        }
    }

    var fileLocation: URL? { fileURL }
}
