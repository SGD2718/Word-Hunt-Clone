#pragma once

#include <cstddef>
#include <string>

namespace wh {

constexpr int kBoardSize = 16;
constexpr int kSide = 4;
constexpr int kMinWordLength = 3;

int scoreForLength(std::size_t length);

// Uppercase ASCII letters only. Returns false on empty input or any
// non-letter byte.
bool normalizeAscii(const char *utf8, std::string &out);

} // namespace wh
