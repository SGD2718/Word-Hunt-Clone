#include "WBGoodBoardGen.hpp"

#include <algorithm>
#include <array>
#include <cstdint>
#include <vector>

#include "WBDealer.hpp"
#include "WHRng.hpp"
#include "WHTrie.hpp"

namespace wb {

namespace {

constexpr int kCandidateCount = 80;
constexpr int kMinSharedLetters = 3;
// Mirrors the WordHunt cap: drop words whose point value exceeds 2600
// (length >= 10) so a single very-long word does not dominate the heuristic.
constexpr int kMaxScoredWordLength = 9;

constexpr uint8_t kDirH = 1;
constexpr uint8_t kDirV = 2;

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
};

struct WordRecord {
    uint32_t wordID;
    uint8_t direction;
    uint8_t length;
    std::array<uint8_t, 26> counts{};
};

void enumerateDfs(const std::vector<DirBlock> &blocks,
                  const wh::Trie &trie,
                  uint32_t nodeIndex,
                  uint16_t usedMask,
                  uint8_t depth,
                  uint8_t direction,
                  std::vector<uint8_t> &seen,
                  std::vector<WordRecord> &out) {
    const wh::TrieNode &node = trie.nodes()[nodeIndex];
    if (node.terminal != wh::kNoWord && node.terminal < seen.size()) {
        if (!seen[node.terminal] && depth >= kMinWordLength
            && depth <= kMaxScoredWordLength) {
            seen[node.terminal] = 1;
            const std::string &w = trie.word(node.terminal);
            WordRecord rec;
            rec.wordID = node.terminal;
            rec.direction = direction;
            rec.length = static_cast<uint8_t>(w.size());
            for (char c : w) rec.counts[static_cast<uint8_t>(c - 'A')]++;
            out.push_back(rec);
        }
    }

    if (depth >= kMaxScoredWordLength) return;

    for (std::size_t i = 0; i < blocks.size(); ++i) {
        uint16_t bit = static_cast<uint16_t>(1u << i);
        if (usedMask & bit) continue;
        const DirBlock &b = blocks[i];

        int32_t next = trie.child(nodeIndex, b.letterA);
        if (next < 0) continue;

        if (!b.isPair()) {
            enumerateDfs(blocks, trie, static_cast<uint32_t>(next),
                         static_cast<uint16_t>(usedMask | bit),
                         static_cast<uint8_t>(depth + 1),
                         direction, seen, out);
        } else {
            int32_t next2 = trie.child(static_cast<uint32_t>(next), b.letterB);
            if (next2 < 0) continue;
            enumerateDfs(blocks, trie, static_cast<uint32_t>(next2),
                         static_cast<uint16_t>(usedMask | bit),
                         static_cast<uint8_t>(depth + 2),
                         direction, seen, out);
        }
    }
}

void enumerateDirection(const std::vector<Block> &blocks,
                        const wh::Trie &trie,
                        uint8_t direction,
                        std::vector<uint8_t> &seenScratch,
                        std::vector<WordRecord> &out) {
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

    std::fill(seenScratch.begin(), seenScratch.end(), 0);

    // Start DFS from each block as the first piece. Trie root is node 0.
    for (std::size_t i = 0; i < usable.size(); ++i) {
        uint16_t bit = static_cast<uint16_t>(1u << i);
        const DirBlock &b = usable[i];
        int32_t next = trie.child(0, b.letterA);
        if (next < 0) continue;
        if (!b.isPair()) {
            enumerateDfs(usable, trie, static_cast<uint32_t>(next),
                         bit, 1, direction, seenScratch, out);
        } else {
            int32_t next2 = trie.child(static_cast<uint32_t>(next), b.letterB);
            if (next2 < 0) continue;
            enumerateDfs(usable, trie, static_cast<uint32_t>(next2),
                         bit, 2, direction, seenScratch, out);
        }
    }
}

int sharedLetterCount(const std::array<uint8_t, 26> &a,
                      const std::array<uint8_t, 26> &b) {
    int total = 0;
    for (int i = 0; i < 26; ++i) {
        total += a[i] < b[i] ? a[i] : b[i];
    }
    return total;
}

int64_t scoreRecords(const std::vector<WordRecord> &words) {
    int64_t sum = 0;
    for (std::size_t i = 0; i < words.size(); ++i) {
        sum += static_cast<int64_t>(words[i].length) * words[i].length;
    }
    for (std::size_t i = 0; i < words.size(); ++i) {
        for (std::size_t j = i + 1; j < words.size(); ++j) {
            if (words[i].direction != words[j].direction) continue;
            int s = sharedLetterCount(words[i].counts, words[j].counts);
            if (s < kMinSharedLetters) continue;
            int maxLen = words[i].length > words[j].length ? words[i].length : words[j].length;
            int64_t contribution = static_cast<int64_t>(s) * s * s / maxLen;
            sum += contribution * 2;
        }
    }
    return sum;
}

int64_t scoreCandidate(const std::vector<Block> &blocks,
                       const wh::Trie &trie,
                       std::vector<uint8_t> &seenScratch,
                       std::vector<WordRecord> &recordScratch,
                       uint32_t &wordCountOut) {
    recordScratch.clear();
    enumerateDirection(blocks, trie, kDirH, seenScratch, recordScratch);
    enumerateDirection(blocks, trie, kDirV, seenScratch, recordScratch);
    wordCountOut = static_cast<uint32_t>(recordScratch.size());
    return scoreRecords(recordScratch);
}

} // namespace

int64_t overlapHeuristicScore(const std::vector<Block> &blocks, const wh::Trie &trie) {
    if (trie.empty()) return 0;
    std::vector<uint8_t> seen(trie.wordCount(), 0);
    std::vector<WordRecord> records;
    uint32_t wc = 0;
    return scoreCandidate(blocks, trie, seen, records, wc);
}

GoodBlocksResult generateGoodBlocks(uint64_t seed, const wh::Trie &trie) {
    wh::Xoshiro256StarStar rng(seed);
    GoodBlocksResult best{};
    best.score = INT64_MIN;
    bool haveBest = false;
    uint32_t evaluated = 0;

    std::vector<uint8_t> seen;
    std::vector<WordRecord> records;
    if (!trie.empty()) {
        seen.assign(trie.wordCount(), 0);
        records.reserve(2048);
    }

    for (int attempt = 0; attempt < kCandidateCount; ++attempt) {
        std::vector<Block> cand = rollBlockSet(rng);
        if (!prefilter(cand)) continue;
        if (trie.empty()) {
            // No trie loaded — fall through with first prefiltered candidate.
            best.blocks = std::move(cand);
            best.score = 0;
            haveBest = true;
            evaluated++;
            break;
        }
        evaluated++;
        uint32_t wc = 0;
        int64_t s = scoreCandidate(cand, trie, seen, records, wc);
        if (!haveBest || s > best.score) {
            best.blocks = cand;
            best.score = s;
            best.wordCount = wc;
            haveBest = true;
        }
    }

    if (!haveBest) {
        // No prefilter survivor; fall back to a fresh roll without filtering.
        best.blocks = rollBlockSet(rng);
        best.score = 0;
        evaluated++;
    }

    placeBlocks(best.blocks, rng);
    best.candidatesEvaluated = evaluated;
    return best;
}

} // namespace wb
