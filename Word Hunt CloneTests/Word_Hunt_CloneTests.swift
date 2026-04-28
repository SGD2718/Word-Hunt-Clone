import XCTest
@testable import Word_Hunt_Clone

final class Word_Hunt_CloneTests: XCTestCase {
    private var engine: WHWordHuntEngine!

    override func setUp() {
        super.setUp()
        engine = WHWordHuntEngine.shared()
    }

    func testXoshiroGeneratedBoardsAreDeterministic() {
        XCTAssertEqual(engine.generateBoard(seed: 1).joined(), "AEIOSIYHTLWNNSVR")
        XCTAssertEqual(engine.generateBoard(seed: 42).joined(), "RTHSITRASWTAESRC")
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

    func testGoodBoardGeneratorIsDeterministicAndSensible() throws {
        try engine.loadBundledDictionary()
        let a = engine.generateGoodBoard(seed: 7)
        let b = engine.generateGoodBoard(seed: 7)
        XCTAssertEqual(a.letters, b.letters)
        XCTAssertEqual(a.letters.count, 16)
        for letter in a.letters {
            XCTAssertEqual(letter.count, 1)
            XCTAssertTrue(letter.unicodeScalars.first.map { CharacterSet.uppercaseLetters.contains($0) } ?? false)
        }
        XCTAssertGreaterThan(a.solverWordCount, 30, "Good board should be findable-rich")
        XCTAssertGreaterThan(Int(a.heuristicScore), 0, "Overlap heuristic should be positive on a populated board")
    }

    func testHeuristicScoresTileSubpathCubedOverMinLen() {
        // CAT path = [0,1,5], CATS path = [0,1,5,6]. Longest contiguous
        // shared cell subsequence = [0,1,5] of length 3. min_len = 3.
        // Pair contribution per matrix entry = 3³/3 = 9; full-matrix sum
        // doubles it = 18. Diagonal: 3² + 4² = 25. Total = 43.
        engine.loadWordsForTesting(["CAT", "CATS"])
        let board = [
            "C", "A", "X", "X",
            "X", "T", "S", "X",
            "X", "X", "X", "X",
            "X", "X", "X", "X"
        ]
        XCTAssertEqual(engine.overlapHeuristicScore(board: board), 43)
    }

    func testOverlapHeuristicDisjointWordsHaveOnlyDiagonal() {
        // CAT and DOG share no cells; tile-LCS = 0. Diagonal: 3² + 3² = 18.
        engine.loadWordsForTesting(["CAT", "DOG"])
        let board = [
            "C", "A", "X", "X",
            "X", "T", "X", "X",
            "X", "X", "D", "O",
            "X", "X", "X", "G"
        ]
        XCTAssertEqual(engine.overlapHeuristicScore(board: board), 18)
    }

    func testTileSequenceDistinguishesFromCellSetOverlap() {
        // RAT and TAR cover the same three cells {0,1,2} but in opposite
        // order. Cell-SET overlap would be 3 (the old heuristic would
        // score this pair); tile-SEQUENCE LCS is only 1 (a single cell
        // matches at any aligned position), which falls below the
        // kMinSubpath threshold and contributes 0. Diagonal: 3² + 3² = 18.
        engine.loadWordsForTesting(["RAT", "TAR"])
        let board = [
            "R", "A", "T", "X",
            "X", "X", "X", "X",
            "X", "X", "X", "X",
            "X", "X", "X", "X"
        ]
        XCTAssertEqual(engine.overlapHeuristicScore(board: board), 18)
    }

    func testGoodBoardBeatsClassicOnFindableWordCount() throws {
        try engine.loadBundledDictionary()
        var goodTotal = 0
        var classicTotal = 0
        let seeds: [UInt64] = [11, 23, 47, 91, 142]
        for s in seeds {
            goodTotal += engine.generateGoodBoard(seed: s).solverWordCount
            classicTotal += engine.solve(board: engine.generateBoard(seed: s)).count
        }
        let goodAvg = Double(goodTotal) / Double(seeds.count)
        let classicAvg = Double(classicTotal) / Double(seeds.count)
        XCTAssertGreaterThan(goodAvg, classicAvg,
            "Good boards should average more findable words than classic dice (\(goodAvg) vs \(classicAvg))")
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
