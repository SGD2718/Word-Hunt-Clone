#pragma once

#include <array>
#include <cstdint>

#include "WHScoring.hpp"

namespace wh {

class Trie;

struct GoodBoardResult {
    std::array<char, kBoardSize> letters{};
    int64_t score = 0;
    uint32_t candidatesEvaluated = 0;
    uint32_t hillClimbAccepted = 0;
    uint32_t wordCount = 0;
};

GoodBoardResult generateGoodBoard(uint64_t seed, const Trie &trie);

// Compute the path-overlap heuristic on an arbitrary board. Exposed for
// debugging and tests.
int64_t overlapHeuristicScore(const std::array<uint8_t, kBoardSize> &board,
                              const Trie &trie);

} // namespace wh
