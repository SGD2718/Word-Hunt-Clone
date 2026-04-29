#pragma once

#include <cstdint>
#include <vector>

#include "WBBlock.hpp"
#include "WHRng.hpp"

namespace wb {

// Rolls 16 Boggle dice, allocates 6 singles + 5 pairs (random orientation),
// then places every block on the grid such that no two blocks touch — not
// even diagonally. The same seed always produces the same letters and
// starting positions.
std::vector<Block> dealAndPlace(uint64_t seed);

// Roll a fresh block set (6 singles + 5 pairs with random orientations) using
// the supplied RNG. All blocks are returned with row=col=-1, inTray=true.
// Pair shapes are coin-flipped per pair; pair.letterB is re-rolled until it
// differs from pair.letterA.
std::vector<Block> rollBlockSet(wh::Xoshiro256StarStar &rng);

// Try to place every block in the supplied list onto the grid using the
// no-touch (including diagonal) constraint. Mutates each block's row/col/
// inTray on success. Returns true if all blocks were placed; on failure the
// blocks may be partially placed and the caller should reset and retry.
// Up to kMaxRestarts internal retries are performed.
bool placeBlocks(std::vector<Block> &blocks, wh::Xoshiro256StarStar &rng);

} // namespace wb
