import SwiftUI

enum GameColors {
    // Background tones (pattern-less solid green like the screenshot's mid tone).
    static let boardBackground = Color(red: 0.45, green: 0.62, blue: 0.40)
    static let boardBorder = Color(red: 0.62, green: 0.80, blue: 0.55)
    static let boardInner = Color(red: 0.28, green: 0.45, blue: 0.28)

    // Default wooden tile (shared with Word Bites).
    static let wood = Color(red: 0.86, green: 0.71, blue: 0.46)
    static let woodHighlight = Color(red: 0.99, green: 0.92, blue: 0.69)

    // Live-status tile fills.
    static let validNew = Color(red: 0.53, green: 0.92, blue: 0.46)
    static let validNewHighlight = Color(red: 0.74, green: 1.0, blue: 0.66)
    static let duplicate = Color(red: 0.99, green: 0.88, blue: 0.40)
    static let duplicateHighlight = Color(red: 1.0, green: 0.95, blue: 0.62)
    static let invalidTile = Color(red: 0.97, green: 0.97, blue: 0.96)
    static let invalidTileHighlight = Color.white

    // Stroke colors.
    static let validStroke = Color.white
    static let invalidStroke = Color(red: 0.95, green: 0.27, blue: 0.22)

    // Toast text/background.
    static let toastValidBackground = Color(red: 0.63, green: 0.96, blue: 0.55)
    static let toastDuplicateBackground = Color(red: 1.0, green: 0.92, blue: 0.50)
    static let toastInvalidBackground = Color.white
    static let toastInk = Color(red: 0.10, green: 0.10, blue: 0.08)

    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
}

extension WordGameModel.LiveStatus {
    var tileFill: (top: Color, bottom: Color) {
        switch self {
        case .empty, .invalid:
            return (GameColors.invalidTileHighlight, GameColors.invalidTile)
        case .duplicate:
            return (GameColors.duplicateHighlight, GameColors.duplicate)
        case .acceptedNew:
            return (GameColors.validNewHighlight, GameColors.validNew)
        }
    }

    var strokeColor: Color {
        switch self {
        case .empty, .invalid:
            return GameColors.invalidStroke
        case .duplicate, .acceptedNew:
            return GameColors.validStroke
        }
    }
}
