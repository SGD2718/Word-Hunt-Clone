#include "WHGoodBoardGen.hpp"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <numeric>
#include <vector>

#include "WHRng.hpp"
#include "WHSolver.hpp"
#include "WHTrie.hpp"

namespace wh {

namespace {

constexpr int kCandidateCount = 200;
constexpr int kHillClimbMaxAccepted = 16;
constexpr int kHillClimbMaxSolves = 60;

constexpr int letterIdx(char c) { return c - 'A'; }

bool isVowelLetter(uint8_t letter) {
    return letter == letterIdx('A') || letter == letterIdx('E') || letter == letterIdx('I')
        || letter == letterIdx('O') || letter == letterIdx('U');
}

int quadrantOf(int cell) {
    int row = cell / kSide;
    int col = cell % kSide;
    return (row / 2) * 2 + (col / 2);
}

struct WeightedLetter {
    char letter;
    int weight;
};

constexpr std::array<WeightedLetter, 5> kVowelWeights = {{
    {'A', 3}, {'E', 5}, {'I', 3}, {'O', 3}, {'U', 1}
}};

constexpr std::array<WeightedLetter, 21> kConsonantWeights = {{
    {'R', 8}, {'S', 8}, {'T', 9}, {'N', 7}, {'L', 6},
    {'C', 5}, {'D', 5}, {'M', 4}, {'H', 4}, {'G', 3},
    {'B', 3}, {'P', 3}, {'F', 3}, {'W', 3}, {'Y', 3},
    {'K', 2}, {'V', 1}, {'J', 1}, {'X', 1}, {'Z', 1},
    {'Q', 1}
}};

bool isRareConsonant(char c) {
    return c == 'J' || c == 'Q' || c == 'X' || c == 'Z' || c == 'V';
}

template <std::size_t N>
char drawWeighted(const std::array<WeightedLetter, N> &pool,
                  Xoshiro256StarStar &rng,
                  const std::array<int, 26> &alreadyDrawnCount,
                  bool capRare) {
    int total = 0;
    for (const auto &entry : pool) {
        bool blocked = capRare && isRareConsonant(entry.letter)
                       && alreadyDrawnCount[letterIdx(entry.letter)] >= 1;
        if (!blocked) {
            total += entry.weight;
        }
    }
    if (total <= 0) {
        return pool[0].letter;
    }
    uint32_t roll = rng.nextBounded(static_cast<uint32_t>(total));
    int acc = 0;
    for (const auto &entry : pool) {
        bool blocked = capRare && isRareConsonant(entry.letter)
                       && alreadyDrawnCount[letterIdx(entry.letter)] >= 1;
        if (blocked) continue;
        acc += entry.weight;
        if (static_cast<uint32_t>(acc) > roll) {
            return entry.letter;
        }
    }
    return pool[N - 1].letter;
}

std::array<char, kBoardSize> generateCandidate(Xoshiro256StarStar &rng) {
    int vowelCount = 5 + static_cast<int>(rng.nextBounded(2));
    std::array<int, 26> drawn{};

    std::vector<char> vowels;
    vowels.reserve(static_cast<std::size_t>(vowelCount));
    for (int i = 0; i < vowelCount; ++i) {
        char c = drawWeighted(kVowelWeights, rng, drawn, false);
        vowels.push_back(c);
        drawn[letterIdx(c)]++;
    }

    int consonantCount = kBoardSize - vowelCount;
    std::vector<char> consonants;
    consonants.reserve(static_cast<std::size_t>(consonantCount));
    for (int i = 0; i < consonantCount; ++i) {
        char c = drawWeighted(kConsonantWeights, rng, drawn, true);
        consonants.push_back(c);
        drawn[letterIdx(c)]++;
    }

    // Q -> U pairing: if Q drawn and no U vowel, swap one non-U vowel for U.
    bool hasQ = std::find(consonants.begin(), consonants.end(), 'Q') != consonants.end();
    bool hasU = std::find(vowels.begin(), vowels.end(), 'U') != vowels.end();
    if (hasQ && !hasU) {
        for (auto &v : vowels) {
            if (v != 'U') {
                drawn[letterIdx(v)]--;
                v = 'U';
                drawn[letterIdx('U')]++;
                break;
            }
        }
    }

    // Quadrant-stratified placement: distribute vowels round-robin across 4
    // quadrants of 4 cells, fill remaining slots with consonants, then shuffle
    // within each quadrant.
    std::array<std::vector<char>, 4> quadrants;
    for (auto &q : quadrants) q.reserve(4);

    for (std::size_t i = 0; i < vowels.size(); ++i) {
        quadrants[i % 4].push_back(vowels[i]);
    }
    int qIndex = 0;
    for (char c : consonants) {
        while (quadrants[qIndex].size() >= 4) {
            qIndex = (qIndex + 1) % 4;
        }
        quadrants[qIndex].push_back(c);
        qIndex = (qIndex + 1) % 4;
    }
    // Top up any quadrant under 4 (rare edge case if vowels piled).
    for (auto &q : quadrants) {
        while (q.size() < 4) {
            q.push_back('E');
        }
    }

    for (auto &q : quadrants) {
        for (int i = static_cast<int>(q.size()) - 1; i > 0; --i) {
            uint32_t j = rng.nextBounded(static_cast<uint32_t>(i + 1));
            std::swap(q[i], q[j]);
        }
    }

    std::array<char, kBoardSize> board{};
    // Quadrant cell layouts (row, col) for each 2x2 block in row-major order:
    static constexpr int kQuadCells[4][4] = {
        {0, 1, 4, 5},
        {2, 3, 6, 7},
        {8, 9, 12, 13},
        {10, 11, 14, 15},
    };
    for (int qi = 0; qi < 4; ++qi) {
        for (int ci = 0; ci < 4; ++ci) {
            board[kQuadCells[qi][ci]] = quadrants[qi][ci];
        }
    }
    return board;
}

bool prefilter(const std::array<char, kBoardSize> &board) {
    const auto &adj = adjacencyMasks();
    std::array<int, 26> counts{};
    int vowelCells = 0;
    int qCell = -1;
    bool hasU = false;
    std::array<bool, kBoardSize> isVowelCell{};

    for (int i = 0; i < kBoardSize; ++i) {
        char c = board[i];
        counts[letterIdx(c)]++;
        bool v = isVowelLetter(static_cast<uint8_t>(letterIdx(c)));
        isVowelCell[i] = v;
        if (v) vowelCells++;
        if (c == 'Q') qCell = i;
        if (c == 'U') hasU = true;
    }

    // Vowel count window.
    if (vowelCells < 4 || vowelCells > 7) return false;

    // Letter count cap.
    for (int x : counts) {
        if (x >= 4) return false;
    }

    // Q must have U within 2 hops.
    if (qCell >= 0) {
        if (!hasU) return false;
        uint16_t reach = adj[qCell];
        uint16_t twoHop = reach;
        uint16_t scan = reach;
        while (scan) {
            int b = __builtin_ctz(scan);
            scan &= scan - 1;
            twoHop |= adj[b];
        }
        twoHop &= ~static_cast<uint16_t>(1u << qCell);
        bool found = false;
        uint16_t s = twoHop;
        while (s) {
            int b = __builtin_ctz(s);
            s &= s - 1;
            if (board[b] == 'U') { found = true; break; }
        }
        if (!found) return false;
    }

    // Rare letters need a vowel neighbor.
    for (int i = 0; i < kBoardSize; ++i) {
        char c = board[i];
        if (c != 'J' && c != 'X' && c != 'Z' && c != 'V') continue;
        uint16_t s = adj[i];
        bool ok = false;
        while (s) {
            int b = __builtin_ctz(s);
            s &= s - 1;
            if (isVowelCell[b]) { ok = true; break; }
        }
        if (!ok) return false;
    }

    // Largest connected consonant-only component <= 9.
    std::array<bool, kBoardSize> visited{};
    int largest = 0;
    for (int i = 0; i < kBoardSize; ++i) {
        if (isVowelCell[i] || visited[i]) continue;
        int size = 0;
        std::array<int, kBoardSize> stack{};
        int top = 0;
        stack[top++] = i;
        visited[i] = true;
        while (top > 0) {
            int n = stack[--top];
            size++;
            uint16_t s = adj[n];
            while (s) {
                int b = __builtin_ctz(s);
                s &= s - 1;
                if (!visited[b] && !isVowelCell[b]) {
                    visited[b] = true;
                    stack[top++] = b;
                }
            }
        }
        if (size > largest) largest = size;
    }
    if (largest > 9) return false;

    return true;
}

constexpr std::array<std::pair<char, char>, 16> kCommonBigrams = {{
    {'T','H'}, {'E','R'}, {'I','N'}, {'O','N'}, {'A','N'}, {'R','E'},
    {'E','D'}, {'E','S'}, {'S','T'}, {'E','N'}, {'A','T'}, {'N','D'},
    {'O','R'}, {'N','G'}, {'I','T'}, {'L','E'}
}};

int countAdjacentBigrams(const std::array<char, kBoardSize> &board) {
    const auto &adj = adjacencyMasks();
    int count = 0;
    for (int i = 0; i < kBoardSize; ++i) {
        uint16_t s = adj[i] & static_cast<uint16_t>(~((1u << (i + 1)) - 1)); // j > i to avoid double-counting
        while (s) {
            int j = __builtin_ctz(s);
            s &= s - 1;
            char a = board[i], b = board[j];
            for (const auto &bg : kCommonBigrams) {
                if ((bg.first == a && bg.second == b) || (bg.first == b && bg.second == a)) {
                    count++;
                    break;
                }
            }
        }
    }
    return count;
}

void analyzePaths(const std::vector<SolverHit> &hits,
                  BoardSubscores &out) {
    int total = static_cast<int>(hits.size());
    out.total = total;
    int n3 = 0, n4 = 0, n5 = 0, n6plus = 0;
    int straight = 0;
    int longest = 0;
    long lengthSum = 0;
    int maxScore = 0;
    std::array<int, 4> turnHist{};
    for (const auto &h : hits) {
        int len = h.length;
        lengthSum += len;
        if (len > longest) longest = len;
        if (len == 3) n3++;
        else if (len == 4) n4++;
        else if (len == 5) n5++;
        else n6plus++;
        maxScore += h.score;

        int turns = 0;
        int prevDr = 99, prevDc = 99;
        for (int i = 1; i < len; ++i) {
            int a = h.path[i - 1], b = h.path[i];
            int dr = (b / kSide) - (a / kSide);
            int dc = (b % kSide) - (a % kSide);
            if (i > 1 && (dr != prevDr || dc != prevDc)) turns++;
            prevDr = dr;
            prevDc = dc;
        }
        if (turns <= 1) straight++;
        if (turns >= 3) turnHist[3]++;
        else turnHist[turns]++;
    }
    out.n3 = n3;
    out.n4 = n4;
    out.n5 = n5;
    out.n6plus = n6plus;
    out.straightBonus = straight;
    out.longestWord = longest;
    out.meanWordLength = total > 0 ? static_cast<double>(lengthSum) / total : 0.0;
    out.solverMaxScore = maxScore;
    out.solverWordCount = total;
    out.turnHistogram = turnHist;
}

double computeScore(const std::array<char, kBoardSize> &board,
                    const std::vector<SolverHit> &hits,
                    BoardSubscores &out) {
    out = BoardSubscores{};
    for (int i = 0; i < kBoardSize; ++i) {
        out.letterCounts[letterIdx(board[i])]++;
        if (isVowelLetter(static_cast<uint8_t>(letterIdx(board[i])))) {
            out.vowelsPerQuadrant[quadrantOf(i)]++;
        }
    }
    analyzePaths(hits, out);
    out.bigramBonus = countAdjacentBigrams(board);

    double mean = 0.0;
    for (int v : out.vowelsPerQuadrant) mean += v;
    mean /= 4.0;
    double var = 0.0;
    for (int v : out.vowelsPerQuadrant) {
        double d = v - mean;
        var += d * d;
    }
    var /= 4.0;
    double balance = 1.0 - var / 2.0;
    if (balance < 0.0) balance = 0.0;
    if (balance > 1.0) balance = 1.0;
    out.vowelBalance = balance;

    // Q penalty if Q present and no U adjacent.
    const auto &adj = adjacencyMasks();
    int qCell = -1;
    for (int i = 0; i < kBoardSize; ++i) if (board[i] == 'Q') { qCell = i; break; }
    if (qCell >= 0) {
        bool uAdj = false;
        uint16_t s = adj[qCell];
        while (s) {
            int b = __builtin_ctz(s);
            s &= s - 1;
            if (board[b] == 'U') { uAdj = true; break; }
        }
        out.qPenalty = uAdj ? 0 : 50;
    }

    out.chaosPenalty = std::max(0, out.total - 220) * 0.5;
    out.sparsePenalty = std::max(0, 50 - out.total) * 3.0;

    double score = 1.0 * out.n3 + 3.0 * out.n4 + 6.0 * out.n5 + 8.0 * out.n6plus
                 + 0.5 * out.straightBonus
                 + 2.0 * out.bigramBonus
                 + 15.0 * out.vowelBalance
                 - out.qPenalty
                 - out.chaosPenalty
                 - out.sparsePenalty;
    return score;
}

std::array<uint8_t, kBoardSize> toBoardLetters(const std::array<char, kBoardSize> &letters) {
    std::array<uint8_t, kBoardSize> out{};
    for (int i = 0; i < kBoardSize; ++i) out[i] = static_cast<uint8_t>(letters[i] - 'A');
    return out;
}

constexpr std::array<char, 5> kVowelSet = {'A', 'E', 'I', 'O', 'U'};
constexpr std::array<char, 10> kCommonConsonants = {'R', 'S', 'T', 'N', 'L', 'C', 'D', 'M', 'H', 'G'};

} // namespace

GoodBoardResult generateGoodBoard(uint64_t seed, const Trie &trie, Solver &solver) {
    Xoshiro256StarStar rng(seed);

    GoodBoardResult best{};
    best.score = -1e18;
    bool haveBest = false;
    uint32_t evaluated = 0;

    for (int attempt = 0; attempt < kCandidateCount; ++attempt) {
        auto cand = generateCandidate(rng);
        if (!prefilter(cand)) continue;
        std::vector<SolverHit> hits = solver.solve(toBoardLetters(cand));
        evaluated++;
        BoardSubscores sub;
        double s = computeScore(cand, hits, sub);
        if (!haveBest || s > best.score) {
            best.letters = cand;
            best.score = s;
            best.subscores = sub;
            haveBest = true;
        }
    }

    if (!haveBest) {
        // Fallback: keep generating without the prefilter; use last candidate.
        auto cand = generateCandidate(rng);
        std::vector<SolverHit> hits = solver.solve(toBoardLetters(cand));
        BoardSubscores sub;
        double s = computeScore(cand, hits, sub);
        best.letters = cand;
        best.score = s;
        best.subscores = sub;
        evaluated++;
    }

    // Hill-climb: try single-letter swaps on the best board.
    int extraSolves = 0;
    int accepted = 0;
    for (int cell = 0; cell < kBoardSize && extraSolves < kHillClimbMaxSolves
                                          && accepted < kHillClimbMaxAccepted; ++cell) {
        bool isV = isVowelLetter(static_cast<uint8_t>(best.letters[cell] - 'A'));
        const char *pool = nullptr;
        int poolSize = 0;
        if (isV) { pool = kVowelSet.data(); poolSize = static_cast<int>(kVowelSet.size()); }
        else { pool = kCommonConsonants.data(); poolSize = static_cast<int>(kCommonConsonants.size()); }

        for (int p = 0; p < poolSize && extraSolves < kHillClimbMaxSolves; ++p) {
            char candLetter = pool[p];
            if (candLetter == best.letters[cell]) continue;
            auto trial = best.letters;
            trial[cell] = candLetter;
            if (!prefilter(trial)) continue;
            std::vector<SolverHit> hits = solver.solve(toBoardLetters(trial));
            extraSolves++;
            evaluated++;
            BoardSubscores sub;
            double s = computeScore(trial, hits, sub);
            if (s > best.score) {
                best.letters = trial;
                best.score = s;
                best.subscores = sub;
                accepted++;
                break; // restart cell scan for this cell's improved baseline
            }
        }
    }

    best.candidatesEvaluated = evaluated;
    best.hillClimbAccepted = static_cast<uint32_t>(accepted);
    return best;
}

} // namespace wh
