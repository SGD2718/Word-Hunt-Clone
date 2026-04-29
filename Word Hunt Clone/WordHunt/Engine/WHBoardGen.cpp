#include "WHBoardGen.hpp"

#include <algorithm>

#include "WHRng.hpp"
#include "WHScoring.hpp"

namespace wh {

std::vector<std::string> generateBoard(uint64_t seed) {
    static constexpr char kDice[kBoardSize][6] = {
        {'A','A','E','E','G','N'}, {'A','B','B','J','O','O'},
        {'A','C','H','O','P','S'}, {'A','F','F','K','P','S'},
        {'A','O','O','T','T','W'}, {'C','I','M','O','T','U'},
        {'D','E','I','L','R','X'}, {'D','E','L','R','V','Y'},
        {'D','I','S','T','T','Y'}, {'E','E','G','H','N','W'},
        {'E','E','I','N','S','U'}, {'E','H','R','T','V','W'},
        {'E','I','O','S','S','T'}, {'E','L','R','T','T','Y'},
        {'H','I','M','N','U','Q'}, {'H','L','N','N','R','Z'},
    };

    Xoshiro256StarStar rng(seed);
    char letters[kBoardSize];
    for (int die = 0; die < kBoardSize; ++die) {
        letters[die] = kDice[die][rng.nextBounded(6)];
    }
    for (int i = kBoardSize - 1; i > 0; --i) {
        uint32_t j = rng.nextBounded(static_cast<uint32_t>(i + 1));
        std::swap(letters[i], letters[j]);
    }

    std::vector<std::string> board;
    board.reserve(kBoardSize);
    for (int index = 0; index < kBoardSize; ++index) {
        board.emplace_back(1, letters[index]);
    }
    return board;
}

} // namespace wh
