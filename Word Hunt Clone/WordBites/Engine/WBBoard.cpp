#include "WBBoard.hpp"

namespace wb {

Board::Board() {
    grid_.clear();
}

void Board::setBlocks(std::vector<Block> blocks) {
    blocks_ = std::move(blocks);
    grid_.clear();
    for (const Block &b : blocks_) {
        if (!b.inTray) {
            writeBlockToGrid(b);
        }
    }
}

bool Board::canPlace(int blockIndex, int row, int col) const {
    if (blockIndex < 0 || blockIndex >= static_cast<int>(blocks_.size())) return false;
    const Block &b = blocks_[blockIndex];
    if (row < 0 || col < 0) return false;

    int needCells = blockCellCount(b.shape);
    int r2 = row, c2 = col;
    if (b.shape == Shape::horizontal) c2 = col + 1;
    if (b.shape == Shape::vertical) r2 = row + 1;
    if (r2 >= kRows || c2 >= kCols) return false;

    auto cellOpen = [&](int r, int c) {
        char existing = grid_.at(r, c);
        if (existing == '\0') return true;
        // Allow the block being moved to overlap its own current cells.
        return blockOccupies(b, r, c);
    };

    if (!cellOpen(row, col)) return false;
    if (needCells == 2 && !cellOpen(r2, c2)) return false;
    return true;
}

bool Board::place(int blockIndex, int row, int col) {
    if (!canPlace(blockIndex, row, col)) return false;
    Block &b = blocks_[blockIndex];
    if (!b.inTray) clearBlockFromGrid(b);
    b.row = static_cast<int8_t>(row);
    b.col = static_cast<int8_t>(col);
    b.inTray = false;
    writeBlockToGrid(b);
    return true;
}

void Board::pickUp(int blockIndex) {
    if (blockIndex < 0 || blockIndex >= static_cast<int>(blocks_.size())) return;
    Block &b = blocks_[blockIndex];
    if (b.inTray) return;
    clearBlockFromGrid(b);
    b.inTray = true;
    b.row = -1;
    b.col = -1;
}

void Board::writeBlockToGrid(const Block &b) {
    grid_.at(b.row, b.col) = static_cast<char>('A' + b.letterA);
    if (b.shape == Shape::horizontal) {
        grid_.at(b.row, b.col + 1) = static_cast<char>('A' + b.letterB);
    } else if (b.shape == Shape::vertical) {
        grid_.at(b.row + 1, b.col) = static_cast<char>('A' + b.letterB);
    }
}

void Board::clearBlockFromGrid(const Block &b) {
    grid_.at(b.row, b.col) = '\0';
    if (b.shape == Shape::horizontal) {
        grid_.at(b.row, b.col + 1) = '\0';
    } else if (b.shape == Shape::vertical) {
        grid_.at(b.row + 1, b.col) = '\0';
    }
}

} // namespace wb
