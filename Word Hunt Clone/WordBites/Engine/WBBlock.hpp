#pragma once

#include <array>
#include <cstdint>

namespace wb {

constexpr int kCols = 8;
constexpr int kRows = 9;
constexpr int kCells = kCols * kRows;

constexpr int kSingleCount = 6;
constexpr int kPairCount = 5;
constexpr int kBlockCount = kSingleCount + kPairCount;

constexpr int kMinWordLength = 3;
constexpr int kMaxHorizontalLength = kCols;
constexpr int kMaxVerticalLength = kRows;

enum class Shape : uint8_t {
    single = 0,
    horizontal = 1,
    vertical = 2,
};

struct Block {
    Shape shape = Shape::single;
    uint8_t letterA = 0;
    uint8_t letterB = 0;
    int8_t row = -1;
    int8_t col = -1;
    bool inTray = true;
};

struct Grid {
    std::array<char, kCells> cells{};

    void clear() { cells.fill('\0'); }
    char at(int row, int col) const { return cells[row * kCols + col]; }
    char &at(int row, int col) { return cells[row * kCols + col]; }
};

inline int blockCellCount(Shape shape) { return shape == Shape::single ? 1 : 2; }

inline bool blockOccupies(const Block &b, int row, int col) {
    if (b.inTray) return false;
    if (b.shape == Shape::single) return b.row == row && b.col == col;
    if (b.shape == Shape::horizontal) {
        return b.row == row && (b.col == col || b.col + 1 == col);
    }
    return b.col == col && (b.row == row || b.row + 1 == row);
}

} // namespace wb
