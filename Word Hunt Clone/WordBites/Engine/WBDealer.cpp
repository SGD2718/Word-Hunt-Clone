#include "WBDealer.hpp"

#include <array>

#include "WHRng.hpp"

namespace wb {

namespace {

constexpr char kDice[16][6] = {
    {'A','A','E','E','G','N'}, {'A','B','B','J','O','O'},
    {'A','C','H','O','P','S'}, {'A','F','F','K','P','S'},
    {'A','O','O','T','T','W'}, {'C','I','M','O','T','U'},
    {'D','E','I','L','R','X'}, {'D','E','L','R','V','Y'},
    {'D','I','S','T','T','Y'}, {'E','E','G','H','N','W'},
    {'E','E','I','N','S','U'}, {'E','H','R','T','V','W'},
    {'E','I','O','S','S','T'}, {'E','L','R','T','T','Y'},
    {'H','I','M','N','U','Q'}, {'H','L','N','N','R','Z'},
};

bool tryPlaceAll(std::vector<Block> &blocks, wh::Xoshiro256StarStar &rng) {
    std::array<bool, kCells> occupied{};

    auto cellBlocked = [&](int r, int c) {
        for (int dr = -1; dr <= 1; ++dr) {
            for (int dc = -1; dc <= 1; ++dc) {
                int nr = r + dr;
                int nc = c + dc;
                if (nr < 0 || nr >= kRows || nc < 0 || nc >= kCols) continue;
                if (occupied[nr * kCols + nc]) return true;
            }
        }
        return false;
    };

    constexpr int kMaxAttemptsPerBlock = 256;
    for (Block &b : blocks) {
        bool placed = false;
        int rowMax = kRows - (b.shape == Shape::vertical ? 1 : 0);
        int colMax = kCols - (b.shape == Shape::horizontal ? 1 : 0);
        for (int attempt = 0; attempt < kMaxAttemptsPerBlock && !placed; ++attempt) {
            int r = static_cast<int>(rng.nextBounded(static_cast<uint32_t>(rowMax)));
            int c = static_cast<int>(rng.nextBounded(static_cast<uint32_t>(colMax)));
            if (cellBlocked(r, c)) continue;
            if (b.shape == Shape::horizontal && cellBlocked(r, c + 1)) continue;
            if (b.shape == Shape::vertical && cellBlocked(r + 1, c)) continue;

            b.row = static_cast<int8_t>(r);
            b.col = static_cast<int8_t>(c);
            b.inTray = false;
            occupied[r * kCols + c] = true;
            if (b.shape == Shape::horizontal) occupied[r * kCols + (c + 1)] = true;
            if (b.shape == Shape::vertical) occupied[(r + 1) * kCols + c] = true;
            placed = true;
        }
        if (!placed) return false;
    }
    return true;
}

} // namespace

std::vector<Block> dealAndPlace(uint64_t seed) {
    wh::Xoshiro256StarStar rng(seed);

    std::array<uint8_t, 16> rolled{};
    for (int die = 0; die < 16; ++die) {
        char face = kDice[die][rng.nextBounded(6)];
        rolled[die] = static_cast<uint8_t>(face - 'A');
    }

    std::vector<Block> blocks;
    blocks.reserve(kBlockCount);

    for (int i = 0; i < kSingleCount; ++i) {
        Block b;
        b.shape = Shape::single;
        b.letterA = rolled[i];
        blocks.push_back(b);
    }
    for (int i = 0; i < kPairCount; ++i) {
        Block b;
        b.shape = (rng.next() & 1ull) ? Shape::horizontal : Shape::vertical;
        int dieA = kSingleCount + i * 2;
        int dieB = kSingleCount + i * 2 + 1;
        b.letterA = rolled[dieA];
        b.letterB = rolled[dieB];
        // A pair's two letters must differ. Re-roll the second die until it
        // lands on a face other than letterA. The Boggle die has 6 faces so
        // duplicates are common (e.g. 'A','A','E','E','G','N'); cap attempts.
        for (int attempt = 0; attempt < 12 && b.letterB == b.letterA; ++attempt) {
            char face = kDice[dieB][rng.nextBounded(6)];
            b.letterB = static_cast<uint8_t>(face - 'A');
        }
        // Fallback: if every face on the die matches letterA (impossible for
        // the standard set, but defensively) bump to the next letter.
        if (b.letterB == b.letterA) {
            b.letterB = static_cast<uint8_t>((b.letterA + 1) % 26);
        }
        blocks.push_back(b);
    }

    constexpr int kMaxRestarts = 32;
    for (int restart = 0; restart < kMaxRestarts; ++restart) {
        for (Block &b : blocks) {
            b.row = -1;
            b.col = -1;
            b.inTray = true;
        }
        if (tryPlaceAll(blocks, rng)) return blocks;
    }
    // Fallback: leave whatever placed; caller should still get a valid block list
    // (any unplaced blocks remain inTray).
    return blocks;
}

} // namespace wb
