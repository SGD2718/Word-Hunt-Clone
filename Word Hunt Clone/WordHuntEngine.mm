#import "WordHuntEngine.h"

#include <array>
#include <cstdint>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#include "Engine/WHBoardGen.hpp"
#include "Engine/WHGoodBoardGen.hpp"
#include "Engine/WHScoring.hpp"
#include "Engine/WHSolver.hpp"
#include "Engine/WHTrie.hpp"

namespace {

bool normalizeWord(NSString *input, std::string &out) {
    return wh::normalizeAscii([input UTF8String], out);
}

NSError *makeError(NSString *message) {
    return [NSError errorWithDomain:@"WordHuntEngine"
                               code:1
                           userInfo:@{NSLocalizedDescriptionKey: message}];
}

bool boardFromArray(NSArray<NSString *> *input, std::array<uint8_t, wh::kBoardSize> &board) {
    if (input.count != wh::kBoardSize) {
        return false;
    }
    for (NSUInteger index = 0; index < input.count; ++index) {
        std::string normalized;
        if (!normalizeWord(input[index], normalized) || normalized.size() != 1) {
            return false;
        }
        board[index] = static_cast<uint8_t>(normalized[0] - 'A');
    }
    return true;
}

NSString *stringFromWord(const std::string &word) {
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

@interface WHGoodBoard ()

- (instancetype)initWithLetters:(NSArray<NSString *> *)letters
                  heuristicScore:(int64_t)score
             candidatesEvaluated:(NSUInteger)evaluated
               hillClimbAccepted:(NSUInteger)accepted
                 solverWordCount:(NSInteger)wordCount;

@end

@implementation WHGoodBoard

- (instancetype)initWithLetters:(NSArray<NSString *> *)letters
                  heuristicScore:(int64_t)score
             candidatesEvaluated:(NSUInteger)evaluated
               hillClimbAccepted:(NSUInteger)accepted
                 solverWordCount:(NSInteger)wordCount {
    self = [super init];
    if (self) {
        _letters = [letters copy];
        _heuristicScore = score;
        _candidatesEvaluated = evaluated;
        _hillClimbAccepted = accepted;
        _solverWordCount = wordCount;
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
    std::unique_ptr<wh::Trie> _trie;
    std::unique_ptr<wh::Solver> _solver;
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
        _trie = std::make_unique<wh::Trie>();
        _solver = std::make_unique<wh::Solver>(*_trie);
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

    _trie->load(std::move(words));
    self.loaded = YES;

    NSInteger wordCount = static_cast<NSInteger>(_trie->wordCount());
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
    _trie->load(std::move(normalizedWords));
    self.loaded = YES;
    self.dictionaryInfo = [[WHDictionaryInfo alloc] initWithWordCount:static_cast<NSInteger>(_trie->wordCount())
                                                            sourceURL:@"testing"
                                                               sha256:@""];
}

- (NSArray<NSString *> *)generateBoardWithSeed:(uint64_t)seed {
    std::vector<std::string> generated = wh::generateBoard(seed);
    NSMutableArray<NSString *> *board = [NSMutableArray arrayWithCapacity:generated.size()];
    for (const std::string &letter : generated) {
        [board addObject:stringFromWord(letter)];
    }
    return board;
}

- (WHGoodBoard *)generateGoodBoardWithSeed:(uint64_t)seed {
    wh::GoodBoardResult result = wh::generateGoodBoard(seed, *_trie);

    NSMutableArray<NSString *> *letters = [NSMutableArray arrayWithCapacity:wh::kBoardSize];
    for (int i = 0; i < wh::kBoardSize; ++i) {
        char c = result.letters[i];
        [letters addObject:[[NSString alloc] initWithBytes:&c length:1 encoding:NSASCIIStringEncoding]];
    }

    return [[WHGoodBoard alloc] initWithLetters:letters
                                  heuristicScore:result.score
                             candidatesEvaluated:result.candidatesEvaluated
                               hillClimbAccepted:result.hillClimbAccepted
                                 solverWordCount:static_cast<NSInteger>(result.wordCount)];
}

- (int64_t)overlapHeuristicScoreForBoard:(NSArray<NSString *> *)board {
    std::array<uint8_t, wh::kBoardSize> normalizedBoard{};
    if (!boardFromArray(board, normalizedBoard)) {
        return 0;
    }
    return wh::overlapHeuristicScore(normalizedBoard, *_trie);
}

- (NSArray<WHWordResult *> *)solveBoard:(NSArray<NSString *> *)board {
    std::array<uint8_t, wh::kBoardSize> normalizedBoard{};
    if (!boardFromArray(board, normalizedBoard)) {
        return @[];
    }

    std::vector<wh::SolverHit> hits = _solver->solve(normalizedBoard);
    NSMutableArray<WHWordResult *> *results = [NSMutableArray arrayWithCapacity:hits.size()];
    for (const wh::SolverHit &hit : hits) {
        NSMutableArray<NSNumber *> *path = [NSMutableArray arrayWithCapacity:hit.length];
        for (uint8_t index = 0; index < hit.length; ++index) {
            [path addObject:@(hit.path[index])];
        }
        NSString *word = stringFromWord(_trie->word(hit.wordID));
        [results addObject:[[WHWordResult alloc] initWithWord:word score:hit.score path:path]];
    }
    return results;
}

- (BOOL)isValidPathForBoard:(NSArray<NSString *> *)board path:(NSArray<NSNumber *> *)path {
    if (board.count != wh::kBoardSize || path.count == 0 || path.count > wh::kBoardSize) {
        return NO;
    }

    const auto &adjacency = wh::adjacencyMasks();
    uint16_t visited = 0;
    int previous = -1;
    for (NSNumber *number in path) {
        int cell = number.intValue;
        if (cell < 0 || cell >= wh::kBoardSize) {
            return NO;
        }
        uint16_t bit = static_cast<uint16_t>(1u << cell);
        if ((visited & bit) != 0) {
            return NO;
        }
        if (previous >= 0 && (adjacency[previous] & bit) == 0) {
            return NO;
        }
        visited |= bit;
        previous = cell;
    }
    return YES;
}

- (BOOL)containsWord:(NSString *)word {
    std::string normalized;
    if (!normalizeWord(word, normalized) || normalized.size() < static_cast<std::size_t>(wh::kMinWordLength)) {
        return NO;
    }
    return _trie->contains(normalized);
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
    return wh::scoreForLength(normalized.size());
}

@end
