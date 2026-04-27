#include "WHSolver.hpp"

#include <algorithm>

namespace wh {

namespace {

std::array<uint16_t, kBoardSize> makeAdjacency() {
    std::array<uint16_t, kBoardSize> adjacency{};
    for (int row = 0; row < kSide; ++row) {
        for (int col = 0; col < kSide; ++col) {
            uint16_t mask = 0;
            for (int dr = -1; dr <= 1; ++dr) {
                for (int dc = -1; dc <= 1; ++dc) {
                    if (dr == 0 && dc == 0) {
                        continue;
                    }
                    int nr = row + dr;
                    int nc = col + dc;
                    if (nr >= 0 && nr < kSide && nc >= 0 && nc < kSide) {
                        mask |= static_cast<uint16_t>(1u << (nr * kSide + nc));
                    }
                }
            }
            adjacency[row * kSide + col] = mask;
        }
    }
    return adjacency;
}

const std::array<uint16_t, kBoardSize> kAdjacency = makeAdjacency();

} // namespace

const std::array<uint16_t, kBoardSize> &adjacencyMasks() {
    return kAdjacency;
}

std::vector<SolverHit> Solver::solve(const std::array<uint8_t, kBoardSize> &board) {
    std::vector<SolverHit> hits;
    if (trie_.empty()) {
        return hits;
    }

    if (seenStamps_.size() != trie_.wordCount()) {
        seenStamps_.assign(trie_.wordCount(), 0);
        stamp_ = 0;
    }

    ++stamp_;
    if (stamp_ == 0) {
        std::fill(seenStamps_.begin(), seenStamps_.end(), 0);
        stamp_ = 1;
    }

    std::array<uint8_t, kBoardSize> path{};
    for (int cell = 0; cell < kBoardSize; ++cell) {
        int32_t node = trie_.child(0, board[cell]);
        if (node >= 0) {
            path[0] = static_cast<uint8_t>(cell);
            dfs(board, static_cast<uint32_t>(node), cell, static_cast<uint16_t>(1u << cell), path, 1, hits);
        }
    }

    std::sort(hits.begin(), hits.end(), [this](const SolverHit &lhs, const SolverHit &rhs) {
        const std::string &leftWord = trie_.word(lhs.wordID);
        const std::string &rightWord = trie_.word(rhs.wordID);
        if (lhs.score != rhs.score) {
            return lhs.score > rhs.score;
        }
        if (leftWord.size() != rightWord.size()) {
            return leftWord.size() > rightWord.size();
        }
        return leftWord < rightWord;
    });

    return hits;
}

void Solver::dfs(const std::array<uint8_t, kBoardSize> &board,
                 uint32_t nodeIndex,
                 int cell,
                 uint16_t visited,
                 std::array<uint8_t, kBoardSize> &path,
                 uint8_t length,
                 std::vector<SolverHit> &hits) {
    const TrieNode &node = trie_.nodes()[nodeIndex];
    if (node.terminal != kNoWord && seenStamps_[node.terminal] != stamp_) {
        seenStamps_[node.terminal] = stamp_;
        SolverHit hit;
        hit.wordID = node.terminal;
        hit.score = scoreForLength(trie_.word(node.terminal).size());
        hit.path = path;
        hit.length = length;
        hits.push_back(hit);
    }

    uint16_t candidates = static_cast<uint16_t>(kAdjacency[cell] & ~visited);
    while (candidates != 0) {
        uint16_t bit = static_cast<uint16_t>(candidates & -candidates);
        int nextCell = __builtin_ctz(candidates);
        candidates &= static_cast<uint16_t>(candidates - 1);

        int32_t nextNode = trie_.child(nodeIndex, board[nextCell]);
        if (nextNode >= 0) {
            path[length] = static_cast<uint8_t>(nextCell);
            dfs(board,
                static_cast<uint32_t>(nextNode),
                nextCell,
                static_cast<uint16_t>(visited | bit),
                path,
                static_cast<uint8_t>(length + 1),
                hits);
        }
    }
}

} // namespace wh
