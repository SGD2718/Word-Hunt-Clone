#pragma once

#include <array>
#include <cstdint>
#include <vector>

#include "WHScoring.hpp"
#include "WHTrie.hpp"

namespace wh {

struct SolverHit {
    uint32_t wordID;
    int score;
    std::array<uint8_t, kBoardSize> path;
    uint8_t length;
};

const std::array<uint16_t, kBoardSize> &adjacencyMasks();

class Solver {
public:
    explicit Solver(const Trie &trie) : trie_(trie) {}

    std::vector<SolverHit> solve(const std::array<uint8_t, kBoardSize> &board);

private:
    void dfs(const std::array<uint8_t, kBoardSize> &board,
             uint32_t nodeIndex,
             int cell,
             uint16_t visited,
             std::array<uint8_t, kBoardSize> &path,
             uint8_t length,
             std::vector<SolverHit> &hits);

    const Trie &trie_;
    std::vector<uint32_t> seenStamps_;
    uint32_t stamp_ = 0;
};

} // namespace wh
