#include "WBSolver.hpp"

#include <algorithm>

#include "WHScoring.hpp"
#include "WHTrie.hpp"

namespace wb {

namespace {

constexpr uint8_t kHBit = 1;
constexpr uint8_t kVBit = 2;

} // namespace

Solver::Solver(const wh::Trie &trie) : trie_(trie) {}

void Solver::scanRunHorizontal(const Grid &grid, int row, int startCol, int endCol,
                               std::vector<WordHit> &hits) const {
    // Only the maximal run itself is considered — no sub-words. Walk the trie
    // through the entire run; if every step has a child and the final node is
    // terminal, emit one hit.
    int len = endCol - startCol + 1;
    if (len < kMinWordLength || len > kMaxHorizontalLength) return;
    uint32_t node = 0;
    for (int i = 0; i < len; ++i) {
        char c = grid.at(row, startCol + i);
        int32_t next = trie_.child(node, static_cast<uint8_t>(c - 'A'));
        if (next < 0) return;
        node = static_cast<uint32_t>(next);
    }
    uint32_t terminal = trie_.nodes()[node].terminal;
    if (terminal == wh::kNoWord) return;
    WordHit hit;
    hit.wordID = terminal;
    hit.row = static_cast<int8_t>(row);
    hit.col = static_cast<int8_t>(startCol);
    hit.length = static_cast<uint8_t>(len);
    hit.orientations = kHBit;
    hit.score = wh::scoreForLength(static_cast<std::size_t>(len));
    hits.push_back(hit);
}

void Solver::scanRunVertical(const Grid &grid, int col, int startRow, int endRow,
                             std::vector<WordHit> &hits) const {
    int len = endRow - startRow + 1;
    if (len < kMinWordLength || len > kMaxVerticalLength) return;
    uint32_t node = 0;
    for (int i = 0; i < len; ++i) {
        char c = grid.at(startRow + i, col);
        int32_t next = trie_.child(node, static_cast<uint8_t>(c - 'A'));
        if (next < 0) return;
        node = static_cast<uint32_t>(next);
    }
    uint32_t terminal = trie_.nodes()[node].terminal;
    if (terminal == wh::kNoWord) return;
    WordHit hit;
    hit.wordID = terminal;
    hit.row = static_cast<int8_t>(startRow);
    hit.col = static_cast<int8_t>(col);
    hit.length = static_cast<uint8_t>(len);
    hit.orientations = kVBit;
    hit.score = wh::scoreForLength(static_cast<std::size_t>(len));
    hits.push_back(hit);
}

void Solver::scanRow(const Grid &grid, int row, std::vector<WordHit> &hits) const {
    int c = 0;
    while (c < kCols) {
        if (grid.at(row, c) == '\0') { ++c; continue; }
        int start = c;
        while (c < kCols && grid.at(row, c) != '\0') ++c;
        int end = c - 1;
        if (end - start + 1 >= kMinWordLength) {
            scanRunHorizontal(grid, row, start, end, hits);
        }
    }
}

void Solver::scanCol(const Grid &grid, int col, std::vector<WordHit> &hits) const {
    int r = 0;
    while (r < kRows) {
        if (grid.at(r, col) == '\0') { ++r; continue; }
        int start = r;
        while (r < kRows && grid.at(r, col) != '\0') ++r;
        int end = r - 1;
        if (end - start + 1 >= kMinWordLength) {
            scanRunVertical(grid, col, start, end, hits);
        }
    }
}

std::vector<WordHit> Solver::findWords(const Grid &grid) const {
    std::vector<WordHit> hits;
    hits.reserve(64);
    for (int r = 0; r < kRows; ++r) scanRow(grid, r, hits);
    for (int c = 0; c < kCols; ++c) scanCol(grid, c, hits);
    coalesce(hits);
    return hits;
}

std::vector<WordHit> Solver::findWordsAffectedBy(const Grid &grid,
                                                 int8_t anchorRow,
                                                 int8_t anchorCol,
                                                 Shape shape) const {
    std::vector<WordHit> hits;
    hits.reserve(16);

    bool didRow[kRows] = {};
    bool didCol[kCols] = {};

    auto doRow = [&](int r) {
        if (r < 0 || r >= kRows || didRow[r]) return;
        didRow[r] = true;
        scanRow(grid, r, hits);
    };
    auto doCol = [&](int c) {
        if (c < 0 || c >= kCols || didCol[c]) return;
        didCol[c] = true;
        scanCol(grid, c, hits);
    };

    switch (shape) {
        case Shape::single:
            doRow(anchorRow);
            doCol(anchorCol);
            break;
        case Shape::horizontal:
            doRow(anchorRow);
            doCol(anchorCol);
            doCol(anchorCol + 1);
            break;
        case Shape::vertical:
            doRow(anchorRow);
            doRow(anchorRow + 1);
            doCol(anchorCol);
            break;
    }

    coalesce(hits);
    return hits;
}

void Solver::coalesce(std::vector<WordHit> &hits) const {
    if (hits.size() < 2) return;
    std::sort(hits.begin(), hits.end(), [](const WordHit &a, const WordHit &b) {
        if (a.wordID != b.wordID) return a.wordID < b.wordID;
        if (a.row != b.row) return a.row < b.row;
        if (a.col != b.col) return a.col < b.col;
        return a.length < b.length;
    });
    std::size_t out = 0;
    for (std::size_t i = 0; i < hits.size(); ++i) {
        if (out > 0 &&
            hits[out - 1].wordID == hits[i].wordID &&
            hits[out - 1].row == hits[i].row &&
            hits[out - 1].col == hits[i].col &&
            hits[out - 1].length == hits[i].length) {
            hits[out - 1].orientations |= hits[i].orientations;
        } else {
            hits[out++] = hits[i];
        }
    }
    hits.resize(out);
}

} // namespace wb
