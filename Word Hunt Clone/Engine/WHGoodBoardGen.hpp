#pragma once

#include <array>
#include <cstdint>
#include <vector>

#include "WHScoring.hpp"

namespace wh {

class Solver;
class Trie;

struct BoardSubscores {
    int n3 = 0;
    int n4 = 0;
    int n5 = 0;
    int n6plus = 0;
    int total = 0;
    int straightBonus = 0;
    int bigramBonus = 0;
    double vowelBalance = 0.0;
    int qPenalty = 0;
    double chaosPenalty = 0.0;
    double sparsePenalty = 0.0;
    int longestWord = 0;
    double meanWordLength = 0.0;
    int solverMaxScore = 0;
    int solverWordCount = 0;
    std::array<int, 26> letterCounts{};
    std::array<int, 4> vowelsPerQuadrant{};
    std::array<int, 4> turnHistogram{}; // 0, 1, 2, 3+ turns
};

struct GoodBoardResult {
    std::array<char, kBoardSize> letters{};
    double score = 0.0;
    BoardSubscores subscores{};
    uint32_t candidatesEvaluated = 0;
    uint32_t hillClimbAccepted = 0;
};

GoodBoardResult generateGoodBoard(uint64_t seed, const Trie &trie, Solver &solver);

} // namespace wh
