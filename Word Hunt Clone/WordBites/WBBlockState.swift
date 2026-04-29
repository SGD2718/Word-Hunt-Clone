import Foundation

struct WBBlockState: Identifiable, Equatable {
    let id: UUID
    let shape: WBShape
    let letterA: String
    let letterB: String
    var row: Int
    var col: Int

    init(id: UUID = UUID(),
         shape: WBShape,
         letterA: String,
         letterB: String,
         row: Int,
         col: Int) {
        self.id = id
        self.shape = shape
        self.letterA = letterA
        self.letterB = letterB
        self.row = row
        self.col = col
    }

    var cellCount: Int { shape == .single ? 1 : 2 }

    var displayText: String { letterB.isEmpty ? letterA : letterA + letterB }

    func cellsOccupied() -> [(row: Int, col: Int)] {
        switch shape {
        case .single: return [(row, col)]
        case .horizontal: return [(row, col), (row, col + 1)]
        case .vertical: return [(row, col), (row + 1, col)]
        @unknown default: return [(row, col)]
        }
    }

    static func == (lhs: WBBlockState, rhs: WBBlockState) -> Bool {
        lhs.id == rhs.id && lhs.row == rhs.row && lhs.col == rhs.col
    }
}
