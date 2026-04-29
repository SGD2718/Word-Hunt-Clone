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

constexpr int kCandidateCount = 240;
constexpr int kHillClimbMaxAccepted = 16;
constexpr int kHillClimbMaxTrials = 60;
constexpr int kMaxScoredWordLength = 9; // bounded by kRows; H runs cap at kCols=8
constexpr int kMaxDecompsPerWord = 4;
constexpr int kMaxBlocksPerWord = kMaxScoredWordLength; // worst case: 9 singles

constexpr std::array<char, 5> kVowelSet = {'A', 'E', 'I', 'O', 'U'};
constexpr std::array<char, 10> kCommonConsonants = {'R', 'S', 'T', 'N', 'L', 'C', 'D', 'M', 'H', 'G'};

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
    for (int n : counts) if (n >= 5) return false;
    if (rareCount > 1) return false;
    if (hasQ && !hasU) return false;
    if (hPairs == 0 || vPairs == 0) return false;
    return true;
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
                       std::vector<uint32_t> &dirty,
                       std::vector<uint8_t> &dedup,
                       std::vector<uint32_t> &dedupDirty,
                       uint32_t &wordCountOut) {
    // Reset scratch buffers using `dirty` from the previous candidate.
    for (uint32_t id : dirty) {
        isFormable[id] = 0;
        decompCount[id] = 0;
        decompsByWord[id].clear();
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
    int64_t total = 0;
    std::vector<uint32_t> neighborScratch;
    neighborScratch.reserve(64);

    for (uint32_t wordID : dirty) {
        const std::string &w = trie.word(wordID);
        int len = static_cast<int>(w.size());
        if (len > kMaxScoredWordLength) continue;
        int64_t selfPts = wh::scoreForLength(static_cast<std::size_t>(len));

        neighborScratch.clear();
        for (const Decomp &d : decompsByWord[wordID]) {
            collectNeighbors(d, usableByDir[d.direction], trie, isFormable, neighborScratch);
        }

        int64_t neighborSqSum = 0;
        for (uint32_t nid : neighborScratch) {
            if (nid == wordID) continue;
            if (dedup[nid]) continue;
            dedup[nid] = 1;
            dedupDirty.push_back(nid);
            int nlen = static_cast<int>(trie.word(nid).size());
            int64_t npts = wh::scoreForLength(static_cast<std::size_t>(nlen));
            neighborSqSum += npts * npts;
        }
        for (uint32_t nid : dedupDirty) dedup[nid] = 0;
        dedupDirty.clear();

        total += selfPts * selfPts + neighborSqSum;
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
    std::vector<uint32_t> dirty;
    std::vector<uint8_t> dedup(wc, 0);
    std::vector<uint32_t> dedupDirty;
    uint32_t out = 0;
    return scoreCandidate(blocks, trie, isFormable, decompCount, decompsByWord,
                          dirty, dedup, dedupDirty, out);
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
    std::vector<uint32_t> dirty;
    std::vector<uint8_t> dedup;
    std::vector<uint32_t> dedupDirty;
    if (!trie.empty()) {
        std::size_t wc = trie.wordCount();
        isFormable.assign(wc, 0);
        decompCount.assign(wc, 0);
        decompsByWord.assign(wc, {});
        dedup.assign(wc, 0);
        dirty.reserve(2048);
        dedupDirty.reserve(64);
    }

    for (int attempt = 0; attempt < kCandidateCount; ++attempt) {
        std::vector<Block> cand = rollBlockSet(rng);
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
                                   decompsByWord, dirty, dedup, dedupDirty, wc);
        if (!haveBest || s > best.score) {
            best.blocks = cand;
            best.score = s;
            best.wordCount = wc;
            haveBest = true;
        }
    }

    if (!haveBest) {
        best.blocks = rollBlockSet(rng);
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
                                       decompsByWord, dirty, dedup, dedupDirty, wc);
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

        for (std::size_t bi = 0;
             bi < best.blocks.size()
                 && hillTrials < kHillClimbMaxTrials
                 && hillAccepted < kHillClimbMaxAccepted;
             ++bi) {
            Block original = best.blocks[bi];

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
                // Pair: try flipping shape, then try replacing letterB with a
                // common consonant. We don't touch letterA — it's set by the
                // first die roll and tends to be the more "anchored" letter.
                Shape origShape = original.shape;
                best.blocks[bi].shape = (origShape == Shape::horizontal)
                    ? Shape::vertical : Shape::horizontal;
                bool acceptedFlip = tryCandidate(original, bi);

                if (!acceptedFlip
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
        }
    }

    placeBlocks(best.blocks, rng);
    best.candidatesEvaluated = evaluated;
    best.hillClimbAccepted = static_cast<uint32_t>(hillAccepted);
    return best;
}

} // namespace wb
