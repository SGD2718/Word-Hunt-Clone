#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace wh {

// Standard New Boggle (1992) 16-die distribution. Deterministic for a given
// seed: rolls one face per die, then shuffles positions (Fisher-Yates).
std::vector<std::string> generateBoard(uint64_t seed);

} // namespace wh
