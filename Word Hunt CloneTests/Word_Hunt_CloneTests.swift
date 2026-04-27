import XCTest
@testable import Word_Hunt_Clone

final class Word_Hunt_CloneTests: XCTestCase {
    private var engine: WHWordHuntEngine!

    override func setUp() {
        super.setUp()
        engine = WHWordHuntEngine.shared()
    }

    func testXoshiroGeneratedBoardsAreDeterministic() {
        XCTAssertEqual(engine.generateBoard(seed: 1).joined(), "LSRDEENOTNAEABDE")
        XCTAssertEqual(engine.generateBoard(seed: 42).joined(), "EOAIAIAOAANDLQAA")
        XCTAssertEqual(engine.generateBoard(seed: 1), engine.generateBoard(seed: 1))
    }

    func testPathValidationAcceptsDiagonalsAndRejectsBadPaths() {
        let board = [
            "C", "A", "R", "E",
            "S", "T", "O", "N",
            "L", "I", "M", "P",
            "D", "U", "G", "S"
        ]

        XCTAssertTrue(engine.isValidPath(board: board, path: path(0, 5, 10)))
        XCTAssertFalse(engine.isValidPath(board: board, path: path(0, 0, 1)))
        XCTAssertFalse(engine.isValidPath(board: board, path: path(0, 3)))
    }

    func testSolverFindsExpectedWordsAndSortsByScoreThenLengthThenAlphabetically() {
        engine.loadWordsForTesting(["CAT", "CAR", "CART", "ART", "TAR"])
        let board = [
            "C", "A", "R", "X",
            "X", "T", "X", "X",
            "X", "X", "X", "X",
            "X", "X", "X", "X"
        ]

        let results = engine.solve(board: board)
        let words = results.map(\.word)

        XCTAssertTrue(words.contains("CART"))
        XCTAssertTrue(words.contains("CAT"))
        XCTAssertTrue(words.contains("CAR"))
        XCTAssertEqual(words.first, "CART")
        XCTAssertEqual(results.first?.score, 400)
    }

    func testBundledDictionaryAssetLoads() throws {
        try engine.loadBundledDictionary()

        XCTAssertTrue(engine.isLoaded)
        XCTAssertGreaterThan(engine.dictionaryInfo?.wordCount ?? 0, 190_000)
        XCTAssertTrue(engine.contains(word: "APPLE"))
        XCTAssertFalse(engine.contains(word: "AA"))
        XCTAssertFalse(engine.contains(word: "NOT_A_WORD"))
    }

    func testSolverPerformanceSmokeTest() throws {
        try engine.loadBundledDictionary()
        let boards = (0..<100).map { engine.generateBoard(seed: UInt64($0)) }

        measure {
            for board in boards {
                _ = engine.solve(board: board)
            }
        }
    }

    private func path(_ values: Int...) -> [NSNumber] {
        values.map(NSNumber.init(value:))
    }
}
