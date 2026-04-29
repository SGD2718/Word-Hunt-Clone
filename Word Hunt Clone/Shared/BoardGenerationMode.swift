import Foundation

enum BoardGenerationMode: String, CaseIterable, Identifiable {
    case good
    case random

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .good: return "Optimized"
        case .random: return "Random"
        }
    }

    var blurb: String {
        switch self {
        case .good:
            return "Heuristic-tuned boards picked from many rolls for richer, higher-scoring solutions."
        case .random:
            return "Vanilla random rolls — every board has equal odds, no quality filtering."
        }
    }
}
