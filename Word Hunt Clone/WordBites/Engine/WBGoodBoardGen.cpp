#include "WBGoodBoardGen.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

#include "WBDealer.hpp"
#include "WHRng.hpp"
#include "WHScoring.hpp"
#include "WHTrie.hpp"

namespace wb {

namespace {

constexpr int kCandidateCount = 1500;
constexpr int kHillClimbMaxPasses = 5;
constexpr int kHillClimbMaxAccepted = 40;
constexpr int kHillClimbMaxTrials = 200;
constexpr int kReachabilityHops = 3;
constexpr int kMaxScoredWordLength = 9; // bounded by kRows; H runs cap at kCols=8
constexpr int kMaxDecompsPerWord = 8;
constexpr int kMaxBlocksPerWord = kMaxScoredWordLength; // worst case: 9 singles

constexpr std::array<char, 5> kVowelSet = {'A', 'E', 'I', 'O', 'U'};
constexpr std::array<char, 10> kCommonConsonants = {'R', 'S', 'T', 'N', 'L', 'C', 'D', 'M', 'H', 'G'};

struct WeightedLetter { char letter; int weight; };

constexpr std::array<WeightedLetter, 5> kVowelWeights = {{
    {'A', 3}, {'E', 5}, {'I', 3}, {'O', 3}, {'U', 1}
}};

// Flatter top vs WordHunt: deliberately deweighting R/S/T/N/L so candidate
// boards spread across more distinct common letters instead of stacking the
// same RSTN family. The neighbor heuristic with squared values otherwise
// snowballs on inflection pairs (RUNNER↔RUNNERS, etc.) which crowds out
// genuinely high-fanout structures.
constexpr std::array<WeightedLetter, 21> kConsonantWeights = {{
    {'R', 5}, {'S', 5}, {'T', 5}, {'N', 5}, {'L', 5},
    {'C', 5}, {'D', 5}, {'M', 4}, {'H', 4}, {'G', 3},
    {'B', 4}, {'P', 4}, {'F', 4}, {'W', 4}, {'Y', 4},
    {'K', 3}, {'V', 2}, {'J', 1}, {'X', 1}, {'Z', 1},
    {'Q', 1}
}};

constexpr uint8_t kDirH = 0;
constexpr uint8_t kDirV = 1;

bool isVowelLetter(uint8_t letter) {
    return letter == 0 || letter == 4 || letter == 8 || letter == 14 || letter == 20; // A E I O U
}

bool isRareConsonant(uint8_t letter) {
    return letter == ('J' - 'A') || letter == ('Q' - 'A')
        || letter == ('X' - 'A') || letter == ('Z' - 'A');
}

bool prefilter(const std::vector<Block> &blocks) {
    std::array<int, 26> counts{};
    int vowels = 0;
    int rareCount = 0;
    int hPairs = 0, vPairs = 0;
    bool hasQ = false, hasU = false;

    for (const Block &b : blocks) {
        counts[b.letterA]++;
        if (isVowelLetter(b.letterA)) vowels++;
        if (isRareConsonant(b.letterA)) rareCount++;
        if (b.letterA == ('Q' - 'A')) hasQ = true;
        if (b.letterA == ('U' - 'A')) hasU = true;

        if (b.shape != Shape::single) {
            counts[b.letterB]++;
            if (isVowelLetter(b.letterB)) vowels++;
            if (isRareConsonant(b.letterB)) rareCount++;
            if (b.letterB == ('Q' - 'A')) hasQ = true;
            if (b.letterB == ('U' - 'A')) hasU = true;
            if (b.shape == Shape::horizontal) hPairs++;
            else vPairs++;
        }
    }

    if (vowels < 4 || vowels > 7) return false;
    for (int n : counts) if (n >= 4) return false;
    if (rareCount > 1) return false;
    if (hasQ && !hasU) return false;
    if (hPairs == 0 || vPairs == 0) return false;

    // Letter diversity: require many distinct letters across the 16 cells, so
    // boards aren't dominated by a single inflection family (lots of E/R/S
    // tiles snowball -ER/-ERS neighbor pairs).
    int distinct = 0;
    for (int n : counts) if (n > 0) distinct++;
    if (distinct < 10) return false;

    static constexpr uint8_t kCommon[] = {
        'B'-'A','C'-'A','D'-'A','F'-'A','G'-'A','H'-'A','L'-'A','M'-'A',
        'N'-'A','P'-'A','R'-'A','S'-'A','T'-'A','W'-'A','Y'-'A'
    };
    int distinctCommon = 0;
    for (uint8_t l : kCommon) if (counts[l] > 0) distinctCommon++;
    if (distinctCommon < 6) return false;

    return true;
}

template <std::size_t N>
char drawWeighted(const std::array<WeightedLetter, N> &pool,
                  wh::Xoshiro256StarStar &rng,
                  const std::array<int, 26> &drawn,
                  bool capRare) {
    int total = 0;
    for (const auto &e : pool) {
        bool blocked = capRare && isRareConsonant(static_cast<uint8_t>(e.letter - 'A'))
                       && drawn[e.letter - 'A'] >= 1;
        if (!blocked) total += e.weight;
    }
    if (total <= 0) return pool[0].letter;
    uint32_t roll = rng.nextBounded(static_cast<uint32_t>(total));
    int acc = 0;
    for (const auto &e : pool) {
        bool blocked = capRare && isRareConsonant(static_cast<uint8_t>(e.letter - 'A'))
                       && drawn[e.letter - 'A'] >= 1;
        if (blocked) continue;
        acc += e.weight;
        if (static_cast<uint32_t>(acc) > roll) return e.letter;
    }
    return pool[N - 1].letter;
}

// Pair letters are sampled from a curated bigram pool rather than as two
// independent letter draws. This deliberately concentrates pair tiles on
// chain-friendly bigrams (CK for -ack/-ock, NG for -ingle/-angle, ER for
// -er/-ers, etc.) which under independent-letter sampling appear far too
// rarely (P(C)*P(K) ~ 0.002 per pair).
struct WeightedBigram { char a, b; int weight; };

constexpr std::array<WeightedBigram, 22> kBigramPool = {{
    {'E','R', 9},  // -er / -ers chains
    {'I','N', 7},  // -in- inserts, -ing chains
    {'N','G', 7},  // -ing, -ingle, -angle
    {'C','K', 6},  // -ack, -ock, -ick chains
    {'L','E', 6},  // -ngle, -mble, -ple endings
    {'E','D', 6},  // past tense
    {'S','T', 5},  // st- prefix
    {'A','T', 5},  // -at- many words
    {'O','N', 5},  // -on- many
    {'A','N', 5},  // -an-
    {'T','H', 4},  // th- prefix
    {'C','H', 4},  // ch- prefix
    {'S','H', 4},  // sh- prefix
    {'R','E', 4},  // re- prefix
    {'E','S', 4},  // -es plurals
    {'A','L', 4},  // -al
    {'O','R', 4},  // -or
    {'L','Y', 3},  // -ly adverbs
    {'A','R', 3},  // -ar
    {'O','U', 3},  // -ou-
    {'I','T', 3},  // -it-
    {'E','L', 3},  // -el-
}};

WeightedBigram drawWeightedBigram(wh::Xoshiro256StarStar &rng) {
    int total = 0;
    for (const auto &e : kBigramPool) total += e.weight;
    uint32_t roll = rng.nextBounded(static_cast<uint32_t>(total));
    int acc = 0;
    for (const auto &e : kBigramPool) {
        acc += e.weight;
        if (static_cast<uint32_t>(acc) > roll) return e;
    }
    return kBigramPool.back();
}

std::vector<Block> rollWeightedBlocks(wh::Xoshiro256StarStar &rng) {
    std::vector<Block> blocks;
    blocks.reserve(kBlockCount);
    std::array<int, 26> drawn{};
    int vowelsUsed = 0;

    // 5 pairs: each from the bigram pool, random orientation.
    for (int i = 0; i < kPairCount; ++i) {
        WeightedBigram bg = drawWeightedBigram(rng);
        Block b;
        b.shape = (rng.next() & 1ull) ? Shape::horizontal : Shape::vertical;
        b.letterA = static_cast<uint8_t>(bg.a - 'A');
        b.letterB = static_cast<uint8_t>(bg.b - 'A');
        if (isVowelLetter(b.letterA)) vowelsUsed++;
        if (isVowelLetter(b.letterB)) vowelsUsed++;
        drawn[b.letterA]++;
        drawn[b.letterB]++;
        blocks.push_back(b);
    }
    // Convention: singles before pairs. Reorder later; for now just append
    // singles to the end, then partition.
    int singlesEmitted = 0;
    auto appendSingle = [&](uint8_t letter) {
        Block b;
        b.shape = Shape::single;
        b.letterA = letter;
        // Insert at front of singles section so final order is singles, pairs.
        blocks.insert(blocks.begin() + singlesEmitted, b);
        singlesEmitted++;
        drawn[letter]++;
    };

    int vowelTarget = 5 + static_cast<int>(rng.nextBounded(2)); // 5 or 6 total
    int vowelSingles = vowelTarget - vowelsUsed;
    if (vowelSingles < 0) vowelSingles = 0;
    if (vowelSingles > kSingleCount) vowelSingles = kSingleCount;
    int consSingles = kSingleCount - vowelSingles;

    for (int i = 0; i < vowelSingles; ++i) {
        char c = drawWeighted(kVowelWeights, rng, drawn, false);
        appendSingle(static_cast<uint8_t>(c - 'A'));
    }
    for (int i = 0; i < consSingles; ++i) {
        char c = drawWeighted(kConsonantWeights, rng, drawn, true);
        appendSingle(static_cast<uint8_t>(c - 'A'));
    }

    // Q->U fixup: if a Q is anywhere in the set and no U, swap a vowel single
    // (or vowel half of a pair) to U.
    bool hasQ = false, hasU = false;
    for (const Block &b : blocks) {
        if (b.letterA == ('Q' - 'A')) hasQ = true;
        if (b.letterA == ('U' - 'A')) hasU = true;
        if (b.shape != Shape::single) {
            if (b.letterB == ('Q' - 'A')) hasQ = true;
            if (b.letterB == ('U' - 'A')) hasU = true;
        }
    }
    if (hasQ && !hasU) {
        for (Block &b : blocks) {
            if (b.shape == Shape::single
                && isVowelLetter(b.letterA)
                && b.letterA != ('U' - 'A')) {
                drawn[b.letterA]--;
                b.letterA = static_cast<uint8_t>('U' - 'A');
                drawn[b.letterA]++;
                hasU = true;
                break;
            }
        }
    }

    return blocks;
}

struct DirBlock {
    uint8_t letterA;
    uint8_t letterB; // 255 for single
    bool isPair() const { return letterB != 255; }
    int letterCount() const { return letterB == 255 ? 1 : 2; }
};

struct Decomp {
    uint8_t direction;
    uint8_t blockCount;
    std::array<uint8_t, kMaxBlocksPerWord> blockIndices{}; // indices into usableByDir[direction]
};

// Walk the trie over a fixed letter buffer. Returns the terminal wordID if
// the buffer is in the dictionary (and length is in range), else kNoWord.
uint32_t lookupTrie(const wh::Trie &trie, const uint8_t *buf, int len) {
    if (len < kMinWordLength || len > kMaxScoredWordLength) return wh::kNoWord;
    uint32_t node = 0;
    for (int i = 0; i < len; ++i) {
        int32_t next = trie.child(node, buf[i]);
        if (next < 0) return wh::kNoWord;
        node = static_cast<uint32_t>(next);
    }
    return trie.nodes()[node].terminal;
}

void enumerateDfs(const std::vector<DirBlock> &blocks,
                  const wh::Trie &trie,
                  uint32_t nodeIndex,
                  uint16_t usedMask,
                  uint8_t depth,
                  uint8_t blockCount,
                  uint8_t direction,
                  std::array<uint8_t, kMaxBlocksPerWord> &pathBlocks,
                  std::vector<uint8_t> &isFormable,
                  std::vector<uint8_t> &decompCount,
                  std::vector<std::vector<Decomp>> &decompsByWord,
                  std::vector<uint32_t> &dirty) {
    const wh::TrieNode &node = trie.nodes()[nodeIndex];
    if (node.terminal != wh::kNoWord && node.terminal < decompCount.size()
        && depth >= kMinWordLength && depth <= kMaxScoredWordLength
        && decompCount[node.terminal] < kMaxDecompsPerWord) {
        if (!isFormable[node.terminal]) {
            isFormable[node.terminal] = 1;
            dirty.push_back(node.terminal);
        }
        Decomp d;
        d.direction = direction;
        d.blockCount = blockCount;
        for (int i = 0; i < blockCount; ++i) d.blockIndices[i] = pathBlocks[i];
        decompsByWord[node.terminal].push_back(d);
        decompCount[node.terminal]++;
    }

    if (depth >= kMaxScoredWordLength) return;

    for (std::size_t i = 0; i < blocks.size(); ++i) {
        uint16_t bit = static_cast<uint16_t>(1u << i);
        if (usedMask & bit) continue;
        const DirBlock &b = blocks[i];

        int32_t next = trie.child(nodeIndex, b.letterA);
        if (next < 0) continue;

        pathBlocks[blockCount] = static_cast<uint8_t>(i);

        if (!b.isPair()) {
            enumerateDfs(blocks, trie, static_cast<uint32_t>(next),
                         static_cast<uint16_t>(usedMask | bit),
                         static_cast<uint8_t>(depth + 1),
                         static_cast<uint8_t>(blockCount + 1),
                         direction, pathBlocks, isFormable, decompCount,
                         decompsByWord, dirty);
        } else {
            int32_t next2 = trie.child(static_cast<uint32_t>(next), b.letterB);
            if (next2 < 0) continue;
            enumerateDfs(blocks, trie, static_cast<uint32_t>(next2),
                         static_cast<uint16_t>(usedMask | bit),
                         static_cast<uint8_t>(depth + 2),
                         static_cast<uint8_t>(blockCount + 1),
                         direction, pathBlocks, isFormable, decompCount,
                         decompsByWord, dirty);
        }
    }
}

std::vector<DirBlock> buildUsable(const std::vector<Block> &blocks, uint8_t direction) {
    std::vector<DirBlock> usable;
    usable.reserve(blocks.size());
    for (const Block &b : blocks) {
        DirBlock db;
        db.letterA = b.letterA;
        if (b.shape == Shape::single) {
            db.letterB = 255;
            usable.push_back(db);
        } else if ((direction == kDirH && b.shape == Shape::horizontal)
                || (direction == kDirV && b.shape == Shape::vertical)) {
            db.letterB = b.letterB;
            usable.push_back(db);
        }
    }
    return usable;
}

// For a decomposition, fill `letters` with the word's letters and `starts`
// with cumulative letter offsets per block; returns total length.
int decompLetters(const Decomp &d, const std::vector<DirBlock> &usable,
                  uint8_t letters[kMaxScoredWordLength + 2],
                  int starts[kMaxBlocksPerWord + 1]) {
    int len = 0;
    starts[0] = 0;
    for (int i = 0; i < d.blockCount; ++i) {
        const DirBlock &b = usable[d.blockIndices[i]];
        letters[len++] = b.letterA;
        if (b.isPair()) letters[len++] = b.letterB;
        starts[i + 1] = len;
    }
    return len;
}

void collectNeighbors(const Decomp &d,
                      const std::vector<DirBlock> &usable,
                      const wh::Trie &trie,
                      const std::vector<uint8_t> &isFormable,
                      std::vector<uint32_t> &neighborsOut) {
    uint8_t letters[kMaxScoredWordLength + 2];
    int starts[kMaxBlocksPerWord + 1];
    int len = decompLetters(d, usable, letters, starts);

    uint8_t buf[kMaxScoredWordLength + 2];

    // Deletions: drop block i, splice the remaining letters together.
    for (int i = 0; i < d.blockCount; ++i) {
        int dropStart = starts[i];
        int dropEnd = starts[i + 1];
        int newLen = len - (dropEnd - dropStart);
        if (newLen < kMinWordLength) continue;
        int p = 0;
        for (int j = 0; j < dropStart; ++j) buf[p++] = letters[j];
        for (int j = dropEnd; j < len; ++j) buf[p++] = letters[j];
        uint32_t id = lookupTrie(trie, buf, newLen);
        if (id != wh::kNoWord && id < isFormable.size() && isFormable[id]) {
            neighborsOut.push_back(id);
        }
    }

    // Insertions: add an unused block at any position between blocks.
    uint16_t used = 0;
    for (int i = 0; i < d.blockCount; ++i) {
        used |= static_cast<uint16_t>(1u << d.blockIndices[i]);
    }
    for (std::size_t u = 0; u < usable.size(); ++u) {
        if (used & static_cast<uint16_t>(1u << u)) continue;
        const DirBlock &ub = usable[u];
        int addLen = ub.letterCount();
        if (len + addLen > kMaxScoredWordLength) continue;
        for (int pos = 0; pos <= d.blockCount; ++pos) {
            int insertAt = starts[pos];
            int p = 0;
            for (int j = 0; j < insertAt; ++j) buf[p++] = letters[j];
            buf[p++] = ub.letterA;
            if (ub.isPair()) buf[p++] = ub.letterB;
            for (int j = insertAt; j < len; ++j) buf[p++] = letters[j];
            uint32_t id = lookupTrie(trie, buf, len + addLen);
            if (id != wh::kNoWord && id < isFormable.size() && isFormable[id]) {
                neighborsOut.push_back(id);
            }
        }
    }

    // Replacements: swap block i for an unused block u (same direction).
    // u may have a different letter count than the block it replaces, so the
    // result's length can differ.
    for (int i = 0; i < d.blockCount; ++i) {
        int dropStart = starts[i];
        int dropEnd = starts[i + 1];
        int afterDropLen = len - (dropEnd - dropStart);
        for (std::size_t u = 0; u < usable.size(); ++u) {
            if (used & static_cast<uint16_t>(1u << u)) continue;
            const DirBlock &ub = usable[u];
            int addLen = ub.letterCount();
            int newLen = afterDropLen + addLen;
            if (newLen < kMinWordLength || newLen > kMaxScoredWordLength) continue;
            int p = 0;
            for (int j = 0; j < dropStart; ++j) buf[p++] = letters[j];
            buf[p++] = ub.letterA;
            if (ub.isPair()) buf[p++] = ub.letterB;
            for (int j = dropEnd; j < len; ++j) buf[p++] = letters[j];
            uint32_t id = lookupTrie(trie, buf, newLen);
            if (id != wh::kNoWord && id < isFormable.size() && isFormable[id]) {
                neighborsOut.push_back(id);
            }
        }
    }
}

int64_t scoreCandidate(const std::vector<Block> &blocks,
                       const wh::Trie &trie,
                       std::vector<uint8_t> &isFormable,
                       std::vector<uint8_t> &decompCount,
                       std::vector<std::vector<Decomp>> &decompsByWord,
                       std::vector<std::vector<uint32_t>> &neighborsByWord,
                       std::vector<uint32_t> &dirty,
                       std::vector<uint8_t> &dedup,
                       std::vector<uint32_t> &dedupDirty,
                       uint32_t &wordCountOut) {
    // Reset scratch buffers using `dirty` from the previous candidate.
    for (uint32_t id : dirty) {
        isFormable[id] = 0;
        decompCount[id] = 0;
        decompsByWord[id].clear();
        neighborsByWord[id].clear();
    }
    dirty.clear();

    std::array<std::vector<DirBlock>, 2> usableByDir;
    usableByDir[kDirH] = buildUsable(blocks, kDirH);
    usableByDir[kDirV] = buildUsable(blocks, kDirV);

    std::array<uint8_t, kMaxBlocksPerWord> pathBuf{};

    auto enumerateOneDir = [&](uint8_t dir) {
        const auto &usable = usableByDir[dir];
        for (std::size_t i = 0; i < usable.size(); ++i) {
            uint16_t bit = static_cast<uint16_t>(1u << i);
            const DirBlock &b = usable[i];
            int32_t next = trie.child(0, b.letterA);
            if (next < 0) continue;
            pathBuf[0] = static_cast<uint8_t>(i);
            if (!b.isPair()) {
                enumerateDfs(usable, trie, static_cast<uint32_t>(next),
                             bit, 1, 1, dir, pathBuf, isFormable,
                             decompCount, decompsByWord, dirty);
            } else {
                int32_t next2 = trie.child(static_cast<uint32_t>(next), b.letterB);
                if (next2 < 0) continue;
                enumerateDfs(usable, trie, static_cast<uint32_t>(next2),
                             bit, 2, 1, dir, pathBuf, isFormable,
                             decompCount, decompsByWord, dirty);
            }
        }
    };

    enumerateOneDir(kDirH);
    enumerateOneDir(kDirV);

    wordCountOut = static_cast<uint32_t>(dirty.size());

    // For each formable word, collect distinct neighbor wordIDs and accumulate score.
    // Pass 1: collect 1-hop neighbor IDs per formable word, deduped.
    std::vector<uint32_t> neighborScratch;
    neighborScratch.reserve(64);
    for (uint32_t wordID : dirty) {
        neighborScratch.clear();
        for (const Decomp &d : decompsByWord[wordID]) {
            collectNeighbors(d, usableByDir[d.direction], trie, isFormable, neighborScratch);
        }
        auto &out = neighborsByWord[wordID];
        out.clear();
        for (uint32_t nid : neighborScratch) {
            if (nid == wordID || dedup[nid]) continue;
            dedup[nid] = 1;
            dedupDirty.push_back(nid);
            out.push_back(nid);
        }
        for (uint32_t nid : dedupDirty) dedup[nid] = 0;
        dedupDirty.clear();
    }

    // Pass 2: score by BFS over the neighbor graph up to kReachabilityHops.
    // Each layer halves the contribution. Together with the symmetric pts(W)
    // self term and the multiplicative cross term, boards with multiple word
    // families bridged by 1-3 block ops score quadratically higher than
    // boards with isolated chains.
    std::vector<uint32_t> currentLayer;
    std::vector<uint32_t> nextLayer;
    currentLayer.reserve(64);
    nextLayer.reserve(64);

    int64_t total = 0;
    for (uint32_t wordID : dirty) {
        int len = static_cast<int>(trie.word(wordID).size());
        if (len > kMaxScoredWordLength) continue;
        int64_t selfPts = wh::scoreForLength(static_cast<std::size_t>(len));

        dedup[wordID] = 1;
        dedupDirty.push_back(wordID);
        currentLayer.clear();
        currentLayer.push_back(wordID);

        int64_t crossSum = 0;
        int64_t hopDivisor = 1;
        for (int hop = 1; hop <= kReachabilityHops; ++hop) {
            if (hop > 1) hopDivisor *= 2;
            nextLayer.clear();
            for (uint32_t cur : currentLayer) {
                for (uint32_t n : neighborsByWord[cur]) {
                    if (dedup[n]) continue;
                    dedup[n] = 1;
                    dedupDirty.push_back(n);
                    nextLayer.push_back(n);
                    int nlen = static_cast<int>(trie.word(n).size());
                    int64_t npts = wh::scoreForLength(static_cast<std::size_t>(nlen));
                    crossSum += (selfPts * npts) / hopDivisor;
                }
            }
            if (nextLayer.empty()) break;
            std::swap(currentLayer, nextLayer);
        }

        for (uint32_t nid : dedupDirty) dedup[nid] = 0;
        dedupDirty.clear();

        total += selfPts * selfPts + crossSum;
    }

    return total;
}

} // namespace

int64_t overlapHeuristicScore(const std::vector<Block> &blocks, const wh::Trie &trie) {
    if (trie.empty()) return 0;
    std::size_t wc = trie.wordCount();
    std::vector<uint8_t> isFormable(wc, 0);
    std::vector<uint8_t> decompCount(wc, 0);
    std::vector<std::vector<Decomp>> decompsByWord(wc);
    std::vector<std::vector<uint32_t>> neighborsByWord(wc);
    std::vector<uint32_t> dirty;
    std::vector<uint8_t> dedup(wc, 0);
    std::vector<uint32_t> dedupDirty;
    uint32_t out = 0;
    return scoreCandidate(blocks, trie, isFormable, decompCount, decompsByWord,
                          neighborsByWord, dirty, dedup, dedupDirty, out);
}

GoodBlocksResult generateGoodBlocks(uint64_t seed, const wh::Trie &trie) {
    wh::Xoshiro256StarStar rng(seed);
    GoodBlocksResult best{};
    best.score = INT64_MIN;
    bool haveBest = false;
    uint32_t evaluated = 0;

    std::vector<uint8_t> isFormable;
    std::vector<uint8_t> decompCount;
    std::vector<std::vector<Decomp>> decompsByWord;
    std::vector<std::vector<uint32_t>> neighborsByWord;
    std::vector<uint32_t> dirty;
    std::vector<uint8_t> dedup;
    std::vector<uint32_t> dedupDirty;
    if (!trie.empty()) {
        std::size_t wc = trie.wordCount();
        isFormable.assign(wc, 0);
        decompCount.assign(wc, 0);
        decompsByWord.assign(wc, {});
        neighborsByWord.assign(wc, {});
        dedup.assign(wc, 0);
        dirty.reserve(2048);
        dedupDirty.reserve(64);
    }

    for (int attempt = 0; attempt < kCandidateCount; ++attempt) {
        std::vector<Block> cand = rollWeightedBlocks(rng);
        if (!prefilter(cand)) continue;
        if (trie.empty()) {
            best.blocks = std::move(cand);
            best.score = 0;
            haveBest = true;
            evaluated++;
            break;
        }
        evaluated++;
        uint32_t wc = 0;
        int64_t s = scoreCandidate(cand, trie, isFormable, decompCount,
                                   decompsByWord, neighborsByWord,
                                   dirty, dedup, dedupDirty, wc);
        if (!haveBest || s > best.score) {
            best.blocks = cand;
            best.score = s;
            best.wordCount = wc;
            haveBest = true;
        }
    }

    if (!haveBest) {
        best.blocks = rollWeightedBlocks(rng);
        best.score = 0;
        evaluated++;
    }

    // Hill climb on the chosen block set. Mutate one block at a time and keep
    // the change if it improves the score. Block placement (row/col) doesn't
    // affect the heuristic, so we mutate letters/shapes here and place once at
    // the end.
    int hillTrials = 0;
    int hillAccepted = 0;
    if (!trie.empty() && haveBest) {
        auto tryCandidate = [&](Block original, std::size_t bi) -> bool {
            if (!prefilter(best.blocks)) {
                best.blocks[bi] = original;
                return false;
            }
            hillTrials++;
            uint32_t wc = 0;
            int64_t s = scoreCandidate(best.blocks, trie, isFormable, decompCount,
                                       decompsByWord, neighborsByWord,
                                       dirty, dedup, dedupDirty, wc);
            evaluated++;
            if (s > best.score) {
                best.score = s;
                best.wordCount = wc;
                hillAccepted++;
                return true;
            }
            best.blocks[bi] = original;
            return false;
        };

        for (int pass = 0;
             pass < kHillClimbMaxPasses
                 && hillTrials < kHillClimbMaxTrials
                 && hillAccepted < kHillClimbMaxAccepted;
             ++pass) {
            int acceptedThisPass = 0;
            for (std::size_t bi = 0;
                 bi < best.blocks.size()
                     && hillTrials < kHillClimbMaxTrials
                     && hillAccepted < kHillClimbMaxAccepted;
                 ++bi) {
                Block original = best.blocks[bi];
                int acceptedBefore = hillAccepted;

                if (original.shape == Shape::single) {
                    bool isV = isVowelLetter(original.letterA);
                    const char *pool = isV ? kVowelSet.data() : kCommonConsonants.data();
                    int poolSize = isV ? static_cast<int>(kVowelSet.size())
                                       : static_cast<int>(kCommonConsonants.size());
                    for (int p = 0; p < poolSize && hillTrials < kHillClimbMaxTrials; ++p) {
                        uint8_t cand = static_cast<uint8_t>(pool[p] - 'A');
                        if (cand == original.letterA) continue;
                        best.blocks[bi].letterA = cand;
                        if (tryCandidate(original, bi)) break;
                    }
                } else {
                    // Pair: try shape flip, then letterA swap, then letterB swap.
                    Shape origShape = original.shape;
                    best.blocks[bi].shape = (origShape == Shape::horizontal)
                        ? Shape::vertical : Shape::horizontal;
                    bool accepted = tryCandidate(original, bi);

                    if (!accepted
                        && hillTrials < kHillClimbMaxTrials
                        && hillAccepted < kHillClimbMaxAccepted) {
                        for (int p = 0;
                             p < static_cast<int>(kCommonConsonants.size())
                                 && hillTrials < kHillClimbMaxTrials;
                             ++p) {
                            uint8_t cand = static_cast<uint8_t>(kCommonConsonants[p] - 'A');
                            if (cand == original.letterA || cand == original.letterB) continue;
                            best.blocks[bi].letterA = cand;
                            if (tryCandidate(original, bi)) { accepted = true; break; }
                        }
                    }

                    if (!accepted
                        && hillTrials < kHillClimbMaxTrials
                        && hillAccepted < kHillClimbMaxAccepted) {
                        for (int p = 0;
                             p < static_cast<int>(kCommonConsonants.size())
                                 && hillTrials < kHillClimbMaxTrials;
                             ++p) {
                            uint8_t cand = static_cast<uint8_t>(kCommonConsonants[p] - 'A');
                            if (cand == original.letterB || cand == original.letterA) continue;
                            best.blocks[bi].letterB = cand;
                            if (tryCandidate(original, bi)) break;
                        }
                    }
                }

                if (hillAccepted > acceptedBefore) acceptedThisPass++;
            }
            if (acceptedThisPass == 0) break; // converged
        }
    }

    placeBlocks(best.blocks, rng);
    best.candidatesEvaluated = evaluated;
    best.hillClimbAccepted = static_cast<uint32_t>(hillAccepted);
    return best;
}

} // namespace wb
