import XCTest
@testable import Word_Hunt_Clone

final class WordBitesEngineTests: XCTestCase {
    private var bites: WBEngine!
    private var hunt: WHWordHuntEngine!

    override func setUp() {
        super.setUp()
        bites = WBEngine.shared()
        hunt = WHWordHuntEngine.shared()
        hunt.loadWordsForTesting(["CAT", "CATS", "AT", "TAR", "RAT", "STAR", "STARS"])
    }

    private func emptyGrid() -> String {
        String(repeating: " ", count: bites.gridCols * bites.gridRows)
    }

    private func placeWord(_ word: String, row: Int, col: Int, horizontal: Bool, in grid: inout [Character]) {
        let cols = bites.gridCols
        for (i, ch) in word.enumerated() {
            let r = horizontal ? row : row + i
            let c = horizontal ? col + i : col
            grid[r * cols + c] = ch
        }
    }

    func testFindWordsHorizontalAndVertical() {
        var grid = Array(emptyGrid())
        placeWord("CAT", row: 2, col: 1, horizontal: true, in: &grid)
        placeWord("STAR", row: 0, col: 5, horizontal: false, in: &grid)
        let s = String(grid)

        let hits = bites.findWords(grid: s)
        let words = Set(hits.map { $0.word })
        XCTAssertTrue(words.contains("CAT"))
        XCTAssertTrue(words.contains("STAR"))

        let cat = hits.first { $0.word == "CAT" }!
        XCTAssertEqual(cat.row, 2)
        XCTAssertEqual(cat.col, 1)
        XCTAssertEqual(cat.length, 3)
        XCTAssertEqual(cat.orientations & 1, 1) // horizontal bit set

        let star = hits.first { $0.word == "STAR" }!
        XCTAssertEqual(star.orientations & 2, 2) // vertical bit set
    }

    func testIncrementalScanMatchesFullScan() {
        var grid = Array(emptyGrid())
        placeWord("CAT", row: 4, col: 2, horizontal: true, in: &grid)
        placeWord("RAT", row: 6, col: 5, horizontal: true, in: &grid)
        let s = String(grid)

        let full = bites.findWords(grid: s)
        // Drop affects row 4 in the area where CAT lives.
        let inc = bites.findWordsAffected(grid: s, row: 4, col: 2, shape: .horizontal)

        let fullWordsTouchingRow4 = Set(full.compactMap { hit -> String? in
            // Either a horizontal hit on row 4, or a vertical hit crossing col 2 or 3
            let touchesRow = hit.row == 4 && (hit.orientations & 1) != 0
            let touchesCol = (hit.col == 2 || hit.col == 3) && (hit.orientations & 2) != 0
            return (touchesRow || touchesCol) ? hit.word : nil
        })
        let incWords = Set(inc.map { $0.word })
        XCTAssertEqual(fullWordsTouchingRow4, incWords)
    }

    func testDealBlocksDeterministicAndPlaced() {
        let a = bites.dealBlocks(seed: 1234)
        let b = bites.dealBlocks(seed: 1234)
        XCTAssertEqual(a.count, b.count)
        XCTAssertEqual(a.count, bites.blockCount)

        for (x, y) in zip(a, b) {
            XCTAssertEqual(x.shape, y.shape)
            XCTAssertEqual(x.letterA, y.letterA)
            XCTAssertEqual(x.letterB, y.letterB)
            XCTAssertEqual(x.row, y.row)
            XCTAssertEqual(x.col, y.col)
        }

        // No two blocks should overlap or touch (even diagonally).
        var occupied = Set<Int>()
        for block in a {
            XCTAssertFalse(block.inTray, "All blocks should start placed on the grid")
            let cells = cellsCovered(block)
            for cell in cells {
                let idx = cell.row * bites.gridCols + cell.col
                XCTAssertFalse(occupied.contains(idx), "Block overlaps another")
                // Check 8-neighbors
                for dr in -1...1 {
                    for dc in -1...1 {
                        let nr = cell.row + dr
                        let nc = cell.col + dc
                        if nr < 0 || nc < 0 || nr >= bites.gridRows || nc >= bites.gridCols { continue }
                        let nidx = nr * bites.gridCols + nc
                        if cells.contains(where: { $0.row == nr && $0.col == nc }) { continue }
                        XCTAssertFalse(occupied.contains(nidx), "Block touches another block")
                    }
                }
            }
            for cell in cells {
                occupied.insert(cell.row * bites.gridCols + cell.col)
            }
        }
    }

    private func cellsCovered(_ block: WBBlockInfo) -> [(row: Int, col: Int)] {
        switch block.shape {
        case .single: return [(block.row, block.col)]
        case .horizontal: return [(block.row, block.col), (block.row, block.col + 1)]
        case .vertical: return [(block.row, block.col), (block.row + 1, block.col)]
        @unknown default: return []
        }
    }
}
