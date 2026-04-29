import SwiftUI

enum BlueGameColors {
    static let boardBackground = Color(red: 0.20, green: 0.40, blue: 0.55)
    static let boardInner = Color(red: 0.14, green: 0.28, blue: 0.42)
    static let boardBorder = Color(red: 0.30, green: 0.55, blue: 0.72)

    // Tile gradient: bright old highlight at the top → darker tan at the bottom.
    static let wood = Color(red: 0.86, green: 0.71, blue: 0.46)
    static let woodHighlight = Color(red: 0.99, green: 0.92, blue: 0.69)
    static let woodShadow = Color(red: 0.68, green: 0.52, blue: 0.30)

    static let gridLine = Color.white.opacity(0.07)
    static let dropValidFill = Color.white.opacity(0.18)
    static let dragInvalidRed = Color.red.opacity(0.55)
    static let dragInvalidTint = Color.red.opacity(0.35)

    static let ink = Color(red: 0.13, green: 0.12, blue: 0.10)
}
