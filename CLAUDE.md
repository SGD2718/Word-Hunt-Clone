# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

iOS SwiftUI Word Hunt clone. Swift UI layer + Objective-C++ engine. iOS 26.2 deployment target, Swift 5.0, iPhone + iPad.

## Build / Run / Test

Open `Word Hunt Clone.xcodeproj` in Xcode. CLI:

```sh
# Build
xcodebuild -project "Word Hunt Clone.xcodeproj" -scheme "Word Hunt Clone" \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test (unit + UI)
xcodebuild -project "Word Hunt Clone.xcodeproj" -scheme "Word Hunt Clone" \
  -destination 'platform=iOS Simulator,name=iPhone 16' test

# Single test
xcodebuild ... test -only-testing:"Word Hunt CloneTests/Word_Hunt_CloneTests/testSolverFindsExpectedWordsAndSortsByScoreThenLengthThenAlphabetically"
```

## Dictionary build

`Resources/WordHuntDictionary.whdict` is a prebuilt binary blob loaded at runtime. To regenerate from a source word list:

```sh
swift Tools/BuildWordList.swift Tools/NWL2023.txt \
  "Word Hunt Clone/Resources/WordHuntDictionary.whdict" \
  "Word Hunt Clone/Resources/WordHuntDictionary.json" \
  [source-url]
```

`.whdict` format: `"WHNWL23"` magic + packed word data. `.json` is the manifest (sha256, word count, source). The engine verifies magic + sha256 on load.

## Architecture

Three layers, each with one job:

1. **`WordHuntEngine.h/.mm`** — Objective-C++ singleton (`WHWordHuntEngine.shared()`). Owns the trie, board generation (xoshiro256** seeded PRNG over a 16-letter Boggle-style cube distribution), DFS solver, path validation, and scoring. All performance-critical code lives here as plain C++ (`std::vector`, packed `TrieNode { firstChild, childMask, terminal }`, 16-bit adjacency masks). Bridged via `Word Hunt Clone-Bridging-Header.h`.

2. **`WordGameModel.swift`** — `ObservableObject` game state. Wraps the engine, holds the 4×4 board, selection path, found words, score, 80-second timer (`roundLength`), and `SubmissionState` enum. All UIKit haptics live here (`UISelectionFeedbackGenerator`, impact generators). Adjacency check is duplicated in Swift (`isAdjacent`) for the selection-path UI logic; the engine re-validates on submit.

3. **`ContentView.swift` / `SolverReviewView.swift` / `AboutView.swift`** — SwiftUI views. `ContentView` is the only large UI file (~550 lines): board grid, drag-gesture path tracking, score/timer HUD. `SolverReviewView` shows `engine.solve(board:)` output after the round ends.

Entry point: `Word_Hunt_CloneApp.swift`.

### Engine ↔ Swift bridge contract

- Board: `[String]` of 16 single-letter uppercase strings, row-major (index = row*4 + col).
- Path: `[NSNumber]` of board indices (`selectedPath.map(NSNumber.init(value:))` in Swift).
- Scoring (length → points): 3=100, 4=400, 5=800, 6=1400, 7=1800, ≥8=2200.
- Words must be ≥3 letters, A–Z only; engine uppercases on load and lookup.
- Solver results (`[WHWordResult]`) sort by score desc, then length desc, then alphabetical.
- Tests inject a custom word list via `engine.loadWordsForTesting(_:)` instead of loading the bundled dictionary.

### Determinism

`generateBoard(seed:)` is deterministic — the test suite pins exact strings for seeds 1 and 42. Don't change the PRNG, the cube face tables, or the draw order without updating those tests.

## Repo layout notes

- `Tools/` — standalone Swift script + raw word lists. Not part of the app target.
- `Word Hunt Clone/Resources/` — bundled dictionary blob + manifest JSON. Both must be in the Copy Bundle Resources phase.
- `Word Hunt CloneTests/` — XCTest unit tests against the engine.
- `Word Hunt CloneUITests/` — XCUITest.
