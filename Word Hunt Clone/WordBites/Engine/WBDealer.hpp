#pragma once

#include <cstdint>
#include <vector>

#include "WBBlock.hpp"

namespace wb {

// Rolls 16 Boggle dice, allocates 6 singles + 5 pairs (random orientation),
// then places every block on the grid such that no two blocks touch — not
// even diagonally. The same seed always produces the same letters and
// starting positions.
std::vector<Block> dealAndPlace(uint64_t seed);

} // namespace wb
