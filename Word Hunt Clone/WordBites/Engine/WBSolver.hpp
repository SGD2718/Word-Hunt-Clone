#pragma once

#include <cstdint>
#include <vector>

#include "WBBlock.hpp"

namespace wh { class Trie; }

namespace wb {

struct WordHit {
    uint32_t wordID;
    int8_t row;
    int8_t col;
    uint8_t length;
    uint8_t orientations; // bit0 = horizontal, bit1 = vertical
    int score;
};

class Solver {
public:
    explicit Solver(const wh::Trie &trie);

    // Full grid scan. Each unique (wordID,row,col,length) appears once with
    // its orientation bits merged.
    std::vector<WordHit> findWords(const Grid &grid) const;

    // Scan only the rows and columns the given block intersects. Used after
    // every drop or pickup. anchorRow/anchorCol is the top-left corner of the
    // block's footprint.
    std::vector<WordHit> findWordsAffectedBy(const Grid &grid,
                                             int8_t anchorRow,
                                             int8_t anchorCol,
                                             Shape shape) const;

private:
    void scanRow(const Grid &grid, int row, std::vector<WordHit> &hits) const;
    void scanCol(const Grid &grid, int col, std::vector<WordHit> &hits) const;
    void scanRunHorizontal(const Grid &grid, int row, int startCol, int endCol,
                           std::vector<WordHit> &hits) const;
    void scanRunVertical(const Grid &grid, int col, int startRow, int endRow,
                         std::vector<WordHit> &hits) const;

    void coalesce(std::vector<WordHit> &hits) const;

    const wh::Trie &trie_;
};

} // namespace wb
