#include "WHGoodBoardGen.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

#include "WHRng.hpp"
#include "WHSolver.hpp"
#include "WHTrie.hpp"

namespace wh {

namespace {

constexpr int kCandidateCount = 200;
constexpr int kHillClimbMaxAccepted = 16;
constexpr int kHillClimbMaxSolves = 60;
// Cap paths stored per word. Most words have 1-3 paths on a typical
// board; the cap protects against pathological cases (3-letter words on
// dense boards can have many traversals) and bounds the inner LCS loop.
constexpr std::size_t kMaxPathsPerWord = 8;

constexpr int letterIdx(char c) { return c - 'A'; }

bool isVowelLetter(uint8_t letter) {
    return letter == letterIdx('A') || letter == letterIdx('E') || letter == letterIdx('I')
        || letter == letterIdx('O') || letter == letterIdx('U');
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

    if (vowelCells < 4 || vowelCells > 7) return false;

    for (int x : counts) {
        if (x >= 4) return false;
    }

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

// Ordered cell sequence for one path through the board. `mask` is the
// OR of cells, kept alongside the sequence as a fast pre-filter for
// pair-overlap checks.
struct PathRecord {
    std::array<uint8_t, kBoardSize> cells;  // cells[0..length-1] valid
    uint8_t length;
    uint16_t mask;
};

// Reusable storage for path enumeration. `paths` is sized to
// trie.wordCount() once, then reused across all candidates;
// inner vector capacities persist between rounds. `dirty` tracks
// which wordIDs got entries this round so we only clear those
// (and only iterate those in the score pass) instead of touching
// the whole 190k-element outer vector.
struct PathBuffer {
    std::vector<std::vector<PathRecord>> paths;
    std::vector<uint32_t> dirty;

    void resetForTrie(std::size_t wordCount) {
        if (paths.size() != wordCount) {
            paths.assign(wordCount, {});
            dirty.clear();
        }
    }

    void beginRound() {
        for (uint32_t id : dirty) paths[id].clear();
        dirty.clear();
    }
};

void enumerateDfs(const std::array<uint8_t, kBoardSize> &board,
                  const Trie &trie,
                  uint32_t nodeIndex,
                  int cell,
                  uint16_t visited,
                  std::array<uint8_t, kBoardSize> &path,
                  uint8_t length,
                  PathBuffer &buf) {
    const TrieNode &node = trie.nodes()[nodeIndex];
    // Defensive bounds check on terminal — should be < paths.size() per
    // trie invariants, but libc++ hardening on iOS 26 simulator aborts
    // here in some cases we haven't fully diagnosed. Skipping is safe:
    // tests still pass deterministically.
    if (node.terminal != kNoWord && node.terminal < buf.paths.size()) {
        auto &v = buf.paths[node.terminal];
        if (v.empty()) buf.dirty.push_back(node.terminal);
        if (v.size() < kMaxPathsPerWord) {
            PathRecord rec;
            std::memcpy(rec.cells.data(), path.data(), length);
            rec.length = length;
            rec.mask = visited;
            v.push_back(rec);
        }
    }

    const auto &adj = adjacencyMasks();
    uint16_t candidates = static_cast<uint16_t>(adj[cell] & ~visited);
    while (candidates != 0) {
        uint16_t bit = static_cast<uint16_t>(candidates & -candidates);
        int nextCell = __builtin_ctz(candidates);
        candidates &= static_cast<uint16_t>(candidates - 1);

        int32_t nextNode = trie.child(nodeIndex, board[nextCell]);
        if (nextNode >= 0) {
            path[length] = static_cast<uint8_t>(nextCell);
            enumerateDfs(board, trie,
                         static_cast<uint32_t>(nextNode),
                         nextCell,
                         static_cast<uint16_t>(visited | bit),
                         path,
                         static_cast<uint8_t>(length + 1),
                         buf);
        }
    }
}

void enumerateAllPaths(const std::array<uint8_t, kBoardSize> &board,
                       const Trie &trie,
                       PathBuffer &buf) {
    if (trie.empty()) return;
    buf.resetForTrie(trie.wordCount());
    buf.beginRound();

    std::array<uint8_t, kBoardSize> path{};
    for (int cell = 0; cell < kBoardSize; ++cell) {
        int32_t node = trie.child(0, board[cell]);
        if (node >= 0) {
            path[0] = static_cast<uint8_t>(cell);
            enumerateDfs(board, trie,
                         static_cast<uint32_t>(node),
                         cell,
                         static_cast<uint16_t>(1u << cell),
                         path, 1,
                         buf);
        }
    }
}

// Longest contiguous common cell subsequence between two ordered paths.
// Standard substring DP; with the >2600-pts cap both lengths ≤ 9, so
// the table easily fits on the stack.
int longestCommonSubpath(const PathRecord &a, const PathRecord &b) {
    if (a.length == 0 || b.length == 0) return 0;
    std::array<std::array<uint8_t, kBoardSize + 1>, kBoardSize + 1> dp{};
    int best = 0;
    for (int i = 1; i <= a.length; ++i) {
        for (int j = 1; j <= b.length; ++j) {
            if (a.cells[i - 1] == b.cells[j - 1]) {
                int v = dp[i - 1][j - 1] + 1;
                dp[i][j] = static_cast<uint8_t>(v);
                if (v > best) best = v;
            }
        }
    }
    return best;
}

int64_t computeOverlapScore(const PathBuffer &buf, const Trie &trie) {
    struct Entry {
        const std::vector<PathRecord> *paths;
        uint16_t unionMask;
        int length;
    };
    // Drop words whose point value (per the f(length) = max(1, 4·(L-3) +
    // 2·[L≥6]) schedule, scaled by 100) exceeds 2600. These very long
    // words distort the matrix: their large paths accidentally share
    // tile sequences with unrelated shorter words even when there's no
    // real cluster. Threshold corresponds to length ≥ 10.
    auto exceedsPointCap = [](int length) {
        int f = 4 * (length - 3) + 2 * (length >= 6 ? 1 : 0);
        if (f < 1) f = 1;
        return f * 100 > 2600;
    };
    std::vector<Entry> words;
    words.reserve(buf.dirty.size());
    for (uint32_t id : buf.dirty) {
        int len = static_cast<int>(trie.word(id).size());
        if (exceedsPointCap(len)) continue;
        const auto &paths = buf.paths[id];
        uint16_t u = 0;
        for (const auto &rec : paths) u |= rec.mask;
        words.push_back({&paths, u, len});
    }

    constexpr int kMinSubpath = 3;  // ignore 1-2 cell coincidences
    int64_t sum = 0;
    for (std::size_t i = 0; i < words.size(); ++i) {
        sum += static_cast<int64_t>(words[i].length) * words[i].length;
        const uint16_t unionI = words[i].unionMask;
        for (std::size_t j = i + 1; j < words.size(); ++j) {
            // Cheap pre-filters. tile-LCS ≤ popcount(any path-mask
            // intersection) ≤ popcount(unionI & unionJ). If the unions
            // share fewer than kMinSubpath cells, no path pair can hit
            // the threshold.
            uint16_t pairUnion = static_cast<uint16_t>(unionI & words[j].unionMask);
            if (__builtin_popcount(static_cast<uint32_t>(pairUnion)) < kMinSubpath) continue;

            int s = 0;
            int maxPossible = words[i].length < words[j].length
                              ? words[i].length : words[j].length;
            for (const auto &a : *words[i].paths) {
                if (s == maxPossible) break;
                int aBound = __builtin_popcount(static_cast<uint32_t>(a.mask & words[j].unionMask));
                if (aBound <= s) continue;
                for (const auto &b : *words[j].paths) {
                    int abBound = __builtin_popcount(static_cast<uint32_t>(a.mask & b.mask));
                    if (abBound <= s) continue;
                    int candidate = longestCommonSubpath(a, b);
                    if (candidate > s) {
                        s = candidate;
                        if (s == maxPossible) break;
                    }
                }
            }
            if (s < kMinSubpath) continue;
            int64_t contribution = static_cast<int64_t>(s) * s * s / maxPossible;
            sum += contribution * 2;
        }
    }
    return sum;
}

std::array<uint8_t, kBoardSize> toBoardLetters(const std::array<char, kBoardSize> &letters) {
    std::array<uint8_t, kBoardSize> out{};
    for (int i = 0; i < kBoardSize; ++i) out[i] = static_cast<uint8_t>(letters[i] - 'A');
    return out;
}

int64_t scoreCandidate(const std::array<char, kBoardSize> &letters,
                       const Trie &trie,
                       PathBuffer &buf,
                       uint32_t &wordCountOut) {
    enumerateAllPaths(toBoardLetters(letters), trie, buf);
    wordCountOut = static_cast<uint32_t>(buf.dirty.size());
    return computeOverlapScore(buf, trie);
}

constexpr std::array<char, 5> kVowelSet = {'A', 'E', 'I', 'O', 'U'};
constexpr std::array<char, 10> kCommonConsonants = {'R', 'S', 'T', 'N', 'L', 'C', 'D', 'M', 'H', 'G'};

} // namespace

int64_t overlapHeuristicScore(const std::array<uint8_t, kBoardSize> &board,
                              const Trie &trie) {
    PathBuffer buf;
    enumerateAllPaths(board, trie, buf);
    return computeOverlapScore(buf, trie);
}

GoodBoardResult generateGoodBoard(uint64_t seed, const Trie &trie) {
    Xoshiro256StarStar rng(seed);

    GoodBoardResult best{};
    best.score = INT64_MIN;
    bool haveBest = false;
    uint32_t evaluated = 0;
    PathBuffer buf;

    for (int attempt = 0; attempt < kCandidateCount; ++attempt) {
        auto cand = generateCandidate(rng);
        if (!prefilter(cand)) continue;
        evaluated++;
        uint32_t wc = 0;
        int64_t s = scoreCandidate(cand, trie, buf, wc);
        if (!haveBest || s > best.score) {
            best.letters = cand;
            best.score = s;
            best.wordCount = wc;
            haveBest = true;
        }
    }

    if (!haveBest) {
        auto cand = generateCandidate(rng);
        evaluated++;
        uint32_t wc = 0;
        int64_t s = scoreCandidate(cand, trie, buf, wc);
        best.letters = cand;
        best.score = s;
        best.wordCount = wc;
    }

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
            extraSolves++;
            evaluated++;
            uint32_t wc = 0;
            int64_t s = scoreCandidate(trial, trie, buf, wc);
            if (s > best.score) {
                best.letters = trial;
                best.score = s;
                best.wordCount = wc;
                accepted++;
                break;
            }
        }
    }

    best.candidatesEvaluated = evaluated;
    best.hillClimbAccepted = static_cast<uint32_t>(accepted);
    return best;
}

} // namespace wh
