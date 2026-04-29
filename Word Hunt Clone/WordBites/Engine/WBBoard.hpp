#pragma once

#include <vector>

#include "WBBlock.hpp"

namespace wb {

class Board {
public:
    Board();

    const Grid &grid() const { return grid_; }
    const std::vector<Block> &blocks() const { return blocks_; }

    void setBlocks(std::vector<Block> blocks);

    bool canPlace(int blockIndex, int row, int col) const;
    bool place(int blockIndex, int row, int col);
    void pickUp(int blockIndex);

private:
    void writeBlockToGrid(const Block &b);
    void clearBlockFromGrid(const Block &b);

    Grid grid_;
    std::vector<Block> blocks_;
};

} // namespace wb
