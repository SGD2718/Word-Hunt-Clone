#import "WordHuntEngine.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <unordered_set>
#include <utility>
#include <vector>

namespace {

constexpr int kBoardSize = 16;
constexpr int kSide = 4;
constexpr int kMinWordLength = 3;
constexpr uint32_t kNoWord = UINT32_MAX;

struct TrieNode {
    uint32_t firstChild = 0;
    uint32_t childMask = 0;
    uint32_t terminal = kNoWord;
};

struct TempNode {
    std::array<int32_t, 26> children;
    uint32_t terminal = kNoWord;

    TempNode() {
        children.fill(-1);
    }
};

struct SolverHit {
    uint32_t wordID;
    int score;
    std::array<uint8_t, kBoardSize> path;
    uint8_t length;
};

static bool normalizeWord(NSString *input, std::string &out) {
    out.clear();
    const char *utf8 = [input UTF8String];
    if (utf8 == nullptr) {
        return false;
    }

    for (const unsigned char *p = reinterpret_cast<const unsigned char *>(utf8); *p != 0; ++p) {
        unsigned char c = *p;
        if (c >= 'a' && c <= 'z') {
            c = static_cast<unsigned char>(c - 'a' + 'A');
        }
        if (c < 'A' || c > 'Z') {
            return false;
        }
        out.push_back(static_cast<char>(c));
    }
    return !out.empty();
}

static int scoreForLength(size_t length) {
    switch (length) {
        case 3: return 100;
        case 4: return 400;
        case 5: return 800;
        case 6: return 1400;
        case 7: return 1800;
        default: return length >= 8 ? 2200 : 0;
    }
}

static std::array<uint16_t, kBoardSize> makeAdjacency() {
    std::array<uint16_t, kBoardSize> adjacency{};
    for (int row = 0; row < kSide; ++row) {
        for (int col = 0; col < kSide; ++col) {
            uint16_t mask = 0;
            for (int dr = -1; dr <= 1; ++dr) {
                for (int dc = -1; dc <= 1; ++dc) {
                    if (dr == 0 && dc == 0) {
                        continue;
                    }
                    int nr = row + dr;
                    int nc = col + dc;
                    if (nr >= 0 && nr < kSide && nc >= 0 && nc < kSide) {
                        mask |= static_cast<uint16_t>(1u << (nr * kSide + nc));
                    }
                }
            }
            adjacency[row * kSide + col] = mask;
        }
    }
    return adjacency;
}

static const std::array<uint16_t, kBoardSize> kAdjacency = makeAdjacency();

class SplitMix64 {
public:
    explicit SplitMix64(uint64_t seed) : state_(seed) {}

    uint64_t next() {
        uint64_t z = (state_ += 0x9E3779B97F4A7C15ULL);
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
        return z ^ (z >> 31);
    }

private:
    uint64_t state_;
};

class Xoshiro256StarStar {
public:
    explicit Xoshiro256StarStar(uint64_t seed) {
        SplitMix64 split(seed);
        for (uint64_t &value : state_) {
            value = split.next();
        }
    }

    uint64_t next() {
        uint64_t result = rotl(state_[1] * 5ULL, 7) * 9ULL;
        uint64_t t = state_[1] << 17;

        state_[2] ^= state_[0];
        state_[3] ^= state_[1];
        state_[1] ^= state_[2];
        state_[0] ^= state_[3];
        state_[2] ^= t;
        state_[3] = rotl(state_[3], 45);

        return result;
    }

    uint32_t nextBounded(uint32_t upperBound) {
        uint64_t threshold = (0ULL - upperBound) % upperBound;
        while (true) {
            uint64_t value = next();
            if (value >= threshold) {
                return static_cast<uint32_t>(value % upperBound);
            }
        }
    }

private:
    static uint64_t rotl(uint64_t value, int shift) {
        return (value << shift) | (value >> (64 - shift));
    }

    std::array<uint64_t, 4> state_{};
};

class WordHuntCore {
public:
    void loadWords(std::vector<std::string> inputWords) {
        std::sort(inputWords.begin(), inputWords.end());
        inputWords.erase(std::unique(inputWords.begin(), inputWords.end()), inputWords.end());

        words_.clear();
        words_.reserve(inputWords.size());
        std::vector<TempNode> temp(1);

        for (const std::string &word : inputWords) {
            if (word.size() < kMinWordLength || word.size() > kBoardSize) {
                continue;
            }

            uint32_t node = 0;
            bool valid = true;
            for (char c : word) {
                if (c < 'A' || c > 'Z') {
                    valid = false;
                    break;
                }
                int letter = c - 'A';
                int32_t child = temp[node].children[letter];
                if (child < 0) {
                    child = static_cast<int32_t>(temp.size());
                    temp[node].children[letter] = child;
                    temp.emplace_back();
                }
                node = static_cast<uint32_t>(child);
            }
            if (!valid || temp[node].terminal != kNoWord) {
                continue;
            }
            temp[node].terminal = static_cast<uint32_t>(words_.size());
            words_.push_back(word);
        }

        nodes_.assign(temp.size(), TrieNode{});
        children_.clear();
        children_.reserve(temp.size() * 2);

        for (size_t index = 0; index < temp.size(); ++index) {
            TrieNode node;
            node.firstChild = static_cast<uint32_t>(children_.size());
            node.terminal = temp[index].terminal;
            for (int letter = 0; letter < 26; ++letter) {
                int32_t child = temp[index].children[letter];
                if (child >= 0) {
                    node.childMask |= (1u << letter);
                    children_.push_back(static_cast<uint32_t>(child));
                }
            }
            nodes_[index] = node;
        }

        seenStamps_.assign(words_.size(), 0);
        stamp_ = 0;
    }

    size_t wordCount() const {
        return words_.size();
    }

    bool contains(const std::string &word) const {
        uint32_t node = 0;
        for (char c : word) {
            if (c < 'A' || c > 'Z') {
                return false;
            }
            int32_t next = child(node, static_cast<uint8_t>(c - 'A'));
            if (next < 0) {
                return false;
            }
            node = static_cast<uint32_t>(next);
        }
        return nodes_[node].terminal != kNoWord;
    }

    std::vector<std::string> generateBoard(uint64_t seed) const {
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

    std::vector<SolverHit> solve(const std::array<uint8_t, kBoardSize> &board) {
        std::vector<SolverHit> hits;
        if (nodes_.empty() || words_.empty()) {
            return hits;
        }

        ++stamp_;
        if (stamp_ == 0) {
            std::fill(seenStamps_.begin(), seenStamps_.end(), 0);
            stamp_ = 1;
        }

        std::array<uint8_t, kBoardSize> path{};
        for (int cell = 0; cell < kBoardSize; ++cell) {
            int32_t node = child(0, board[cell]);
            if (node >= 0) {
                path[0] = static_cast<uint8_t>(cell);
                dfs(board, static_cast<uint32_t>(node), cell, static_cast<uint16_t>(1u << cell), path, 1, hits);
            }
        }

        std::sort(hits.begin(), hits.end(), [this](const SolverHit &lhs, const SolverHit &rhs) {
            const std::string &leftWord = words_[lhs.wordID];
            const std::string &rightWord = words_[rhs.wordID];
            if (lhs.score != rhs.score) {
                return lhs.score > rhs.score;
            }
            if (leftWord.size() != rightWord.size()) {
                return leftWord.size() > rightWord.size();
            }
            return leftWord < rightWord;
        });

        return hits;
    }

    const std::string &word(uint32_t id) const {
        return words_[id];
    }

private:
    int32_t child(uint32_t nodeIndex, uint8_t letter) const {
        const TrieNode &node = nodes_[nodeIndex];
        uint32_t bit = 1u << letter;
        if ((node.childMask & bit) == 0) {
            return -1;
        }
        uint32_t lowerMask = node.childMask & (bit - 1);
        uint32_t offset = static_cast<uint32_t>(__builtin_popcount(lowerMask));
        return static_cast<int32_t>(children_[node.firstChild + offset]);
    }

    void dfs(const std::array<uint8_t, kBoardSize> &board,
             uint32_t nodeIndex,
             int cell,
             uint16_t visited,
             std::array<uint8_t, kBoardSize> &path,
             uint8_t length,
             std::vector<SolverHit> &hits) {
        const TrieNode &node = nodes_[nodeIndex];
        if (node.terminal != kNoWord && seenStamps_[node.terminal] != stamp_) {
            seenStamps_[node.terminal] = stamp_;
            SolverHit hit;
            hit.wordID = node.terminal;
            hit.score = scoreForLength(words_[node.terminal].size());
            hit.path = path;
            hit.length = length;
            hits.push_back(hit);
        }

        uint16_t candidates = static_cast<uint16_t>(kAdjacency[cell] & ~visited);
        while (candidates != 0) {
            uint16_t bit = static_cast<uint16_t>(candidates & -candidates);
            int nextCell = __builtin_ctz(candidates);
            candidates &= static_cast<uint16_t>(candidates - 1);

            int32_t nextNode = child(nodeIndex, board[nextCell]);
            if (nextNode >= 0) {
                path[length] = static_cast<uint8_t>(nextCell);
                dfs(board,
                    static_cast<uint32_t>(nextNode),
                    nextCell,
                    static_cast<uint16_t>(visited | bit),
                    path,
                    static_cast<uint8_t>(length + 1),
                    hits);
            }
        }
    }

    std::vector<TrieNode> nodes_;
    std::vector<uint32_t> children_;
    std::vector<std::string> words_;
    std::vector<uint32_t> seenStamps_;
    uint32_t stamp_ = 0;
};

static NSError *makeError(NSString *message) {
    return [NSError errorWithDomain:@"WordHuntEngine"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

static bool boardFromArray(NSArray<NSString *> *input, std::array<uint8_t, kBoardSize> &board) {
    if (input.count != kBoardSize) {
        return false;
    }

    for (NSUInteger index = 0; index < input.count; ++index) {
        NSString *letterString = input[index];
        std::string normalized;
        if (!normalizeWord(letterString, normalized) || normalized.size() != 1) {
            return false;
        }
        board[index] = static_cast<uint8_t>(normalized[0] - 'A');
    }
    return true;
}

static NSString *stringFromWord(const std::string &word) {
    return [[NSString alloc] initWithBytes:word.data()
                                    length:word.size()
                                  encoding:NSUTF8StringEncoding];
}

} // namespace

@implementation WHWordResult

- (instancetype)initWithWord:(NSString *)word score:(NSInteger)score path:(NSArray<NSNumber *> *)path {
    self = [super init];
    if (self) {
        _word = [word copy];
        _score = score;
        _path = [path copy];
    }
    return self;
}

@end

@implementation WHDictionaryInfo

- (instancetype)initWithWordCount:(NSInteger)wordCount sourceURL:(NSString *)sourceURL sha256:(NSString *)sha256 {
    self = [super init];
    if (self) {
        _wordCount = wordCount;
        _sourceURL = [sourceURL copy];
        _sha256 = [sha256 copy];
    }
    return self;
}

@end

@interface WHWordHuntEngine ()

@property (nonatomic) BOOL loaded;
@property (nonatomic, nullable) WHDictionaryInfo *dictionaryInfo;

@end

@implementation WHWordHuntEngine {
    std::unique_ptr<WordHuntCore> _core;
}

+ (instancetype)sharedEngine {
    static WHWordHuntEngine *engine;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        engine = [[WHWordHuntEngine alloc] initPrivate];
    });
    return engine;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _core = std::make_unique<WordHuntCore>();
    }
    return self;
}

- (instancetype)init {
    return [WHWordHuntEngine sharedEngine];
}

- (BOOL)loadBundledDictionaryWithError:(NSError **)error {
    NSURL *dictionaryURL = [[NSBundle mainBundle] URLForResource:@"WordHuntDictionary" withExtension:@"whdict"];
    NSURL *manifestURL = [[NSBundle mainBundle] URLForResource:@"WordHuntDictionary" withExtension:@"json"];
    if (dictionaryURL == nil) {
        if (error != nullptr) {
            *error = makeError(@"WordHuntDictionary.whdict is missing from the app bundle.");
        }
        return NO;
    }

    NSData *data = [NSData dataWithContentsOfURL:dictionaryURL options:NSDataReadingMappedIfSafe error:error];
    if (data == nil) {
        return NO;
    }

    const uint8_t *bytes = static_cast<const uint8_t *>(data.bytes);
    NSUInteger size = data.length;
    if (size < 12 || std::memcmp(bytes, "WHNWL23", 7) != 0) {
        if (error != nullptr) {
            *error = makeError(@"WordHuntDictionary.whdict has an invalid header.");
        }
        return NO;
    }

    uint32_t count = 0;
    std::memcpy(&count, bytes + 8, sizeof(uint32_t));
    NSUInteger offset = 12;
    std::vector<std::string> words;
    words.reserve(count);
    for (uint32_t index = 0; index < count; ++index) {
        if (offset >= size) {
            if (error != nullptr) {
                *error = makeError(@"WordHuntDictionary.whdict ended before all words were read.");
            }
            return NO;
        }
        uint8_t length = bytes[offset++];
        if (length == 0 || offset + length > size) {
            if (error != nullptr) {
                *error = makeError(@"WordHuntDictionary.whdict contains an invalid word length.");
            }
            return NO;
        }
        words.emplace_back(reinterpret_cast<const char *>(bytes + offset), length);
        offset += length;
    }

    _core->loadWords(std::move(words));
    self.loaded = YES;

    NSInteger wordCount = static_cast<NSInteger>(_core->wordCount());
    NSString *sourceURL = @"https://github.com/Ammaar-Alam/wordhunt-solver/blob/main/dictionary.txt";
    NSString *sha256 = @"";
    if (manifestURL != nil) {
        NSData *manifestData = [NSData dataWithContentsOfURL:manifestURL];
        if (manifestData != nil) {
            NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:manifestData options:0 error:nil];
            if ([manifest isKindOfClass:[NSDictionary class]]) {
                NSNumber *manifestCount = manifest[@"wordCount"];
                NSString *manifestSource = manifest[@"sourceURL"];
                NSString *manifestSHA = manifest[@"sha256"];
                if ([manifestCount respondsToSelector:@selector(integerValue)]) {
                    wordCount = manifestCount.integerValue;
                }
                if ([manifestSource isKindOfClass:[NSString class]]) {
                    sourceURL = manifestSource;
                }
                if ([manifestSHA isKindOfClass:[NSString class]]) {
                    sha256 = manifestSHA;
                }
            }
        }
    }
    self.dictionaryInfo = [[WHDictionaryInfo alloc] initWithWordCount:wordCount sourceURL:sourceURL sha256:sha256];
    return YES;
}

- (void)loadWordsForTesting:(NSArray<NSString *> *)words {
    std::vector<std::string> normalizedWords;
    normalizedWords.reserve(words.count);
    for (NSString *word in words) {
        std::string normalized;
        if (normalizeWord(word, normalized)) {
            normalizedWords.push_back(std::move(normalized));
        }
    }
    _core->loadWords(std::move(normalizedWords));
    self.loaded = YES;
    self.dictionaryInfo = [[WHDictionaryInfo alloc] initWithWordCount:static_cast<NSInteger>(_core->wordCount())
                                                            sourceURL:@"testing"
                                                               sha256:@""];
}

- (NSArray<NSString *> *)generateBoardWithSeed:(uint64_t)seed {
    std::vector<std::string> generated = _core->generateBoard(seed);
    NSMutableArray<NSString *> *board = [NSMutableArray arrayWithCapacity:generated.size()];
    for (const std::string &letter : generated) {
        [board addObject:stringFromWord(letter)];
    }
    return board;
}

- (NSArray<WHWordResult *> *)solveBoard:(NSArray<NSString *> *)board {
    std::array<uint8_t, kBoardSize> normalizedBoard{};
    if (!boardFromArray(board, normalizedBoard)) {
        return @[];
    }

    std::vector<SolverHit> hits = _core->solve(normalizedBoard);
    NSMutableArray<WHWordResult *> *results = [NSMutableArray arrayWithCapacity:hits.size()];
    for (const SolverHit &hit : hits) {
        NSMutableArray<NSNumber *> *path = [NSMutableArray arrayWithCapacity:hit.length];
        for (uint8_t index = 0; index < hit.length; ++index) {
            [path addObject:@(hit.path[index])];
        }
        NSString *word = stringFromWord(_core->word(hit.wordID));
        [results addObject:[[WHWordResult alloc] initWithWord:word score:hit.score path:path]];
    }
    return results;
}

- (BOOL)isValidPathForBoard:(NSArray<NSString *> *)board path:(NSArray<NSNumber *> *)path {
    if (board.count != kBoardSize || path.count == 0 || path.count > kBoardSize) {
        return NO;
    }

    uint16_t visited = 0;
    int previous = -1;
    for (NSNumber *number in path) {
        int cell = number.intValue;
        if (cell < 0 || cell >= kBoardSize) {
            return NO;
        }
        uint16_t bit = static_cast<uint16_t>(1u << cell);
        if ((visited & bit) != 0) {
            return NO;
        }
        if (previous >= 0 && (kAdjacency[previous] & bit) == 0) {
            return NO;
        }
        visited |= bit;
        previous = cell;
    }
    return YES;
}

- (BOOL)containsWord:(NSString *)word {
    std::string normalized;
    if (!normalizeWord(word, normalized) || normalized.size() < kMinWordLength) {
        return NO;
    }
    return _core->contains(normalized);
}

- (NSString *)wordForBoard:(NSArray<NSString *> *)board path:(NSArray<NSNumber *> *)path {
    if (![self isValidPathForBoard:board path:path]) {
        return @"";
    }

    NSMutableString *word = [NSMutableString stringWithCapacity:path.count];
    for (NSNumber *number in path) {
        NSInteger index = number.integerValue;
        if (index < 0 || index >= static_cast<NSInteger>(board.count)) {
            return @"";
        }
        NSString *letter = board[static_cast<NSUInteger>(index)].uppercaseString;
        if (letter.length != 1) {
            return @"";
        }
        [word appendString:letter];
    }
    return word;
}

- (NSInteger)scoreForWord:(NSString *)word {
    std::string normalized;
    if (!normalizeWord(word, normalized)) {
        return 0;
    }
    return scoreForLength(normalized.size());
}

@end
