#pragma once

#include <cstdint>
#include <vector>

#include "WBBlock.hpp"

namespace wh { class Trie; }

namespace wb {

struct GoodBlocksResult {
    std::vector<Block> blocks;
    int64_t score = 0;
    uint32_t candidatesEvaluated = 0;
    uint32_t hillClimbAccepted = 0;
    uint32_t wordCount = 0;
};

// Generate a "good" Word Bites block set: 80 random candidates are scored by a
// directional letter-overlap heuristic and the highest-scoring candidate is
// returned. Blocks are returned unplaced (inTray=true, row=col=-1); the caller
// runs placeBlocks() to position them.
GoodBlocksResult generateGoodBlocks(uint64_t seed, const wh::Trie &trie);

// Compute the heuristic score for an arbitrary block set. Exposed for tests.
int64_t overlapHeuristicScore(const std::vector<Block> &blocks, const wh::Trie &trie);

} // namespace wb
