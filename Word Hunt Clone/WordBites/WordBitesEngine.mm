#import "WordBitesEngine.h"
#import "WordHuntEngine+Internal.h"

#include <memory>
#include <string>
#include <vector>

#include "WBBlock.hpp"
#include "WBDealer.hpp"
#include "WBGoodBoardGen.hpp"
#include "WBSolver.hpp"
#include "WHTrie.hpp"

namespace {

NSString *letterString(uint8_t letter) {
    char c = static_cast<char>('A' + letter);
    return [[NSString alloc] initWithBytes:&c length:1 encoding:NSASCIIStringEncoding];
}

WBShape shapeToObjC(wb::Shape s) {
    switch (s) {
        case wb::Shape::single: return WBShapeSingle;
        case wb::Shape::horizontal: return WBShapeHorizontal;
        case wb::Shape::vertical: return WBShapeVertical;
    }
}

wb::Shape shapeToCpp(WBShape s) {
    switch (s) {
        case WBShapeHorizontal: return wb::Shape::horizontal;
        case WBShapeVertical: return wb::Shape::vertical;
        case WBShapeSingle:
        default: return wb::Shape::single;
    }
}

bool gridFromString(NSString *flat, wb::Grid &grid) {
    if (flat.length != static_cast<NSUInteger>(wb::kCells)) return false;
    grid.clear();
    for (NSUInteger i = 0; i < flat.length; ++i) {
        unichar ch = [flat characterAtIndex:i];
        if (ch >= 'a' && ch <= 'z') ch = static_cast<unichar>(ch - 'a' + 'A');
        if (ch >= 'A' && ch <= 'Z') {
            grid.cells[i] = static_cast<char>(ch);
        } else {
            grid.cells[i] = '\0';
        }
    }
    return true;
}

} // namespace

@interface WBBlockInfo ()
- (instancetype)initWithBlock:(const wb::Block &)block;
@end

@implementation WBBlockInfo

- (instancetype)initWithBlock:(const wb::Block &)block {
    self = [super init];
    if (self) {
        _shape = shapeToObjC(block.shape);
        _letterA = letterString(block.letterA);
        _letterB = block.shape == wb::Shape::single ? @"" : letterString(block.letterB);
        _row = block.row;
        _col = block.col;
        _inTray = block.inTray ? YES : NO;
    }
    return self;
}

@end

@interface WBWordHit ()
- (instancetype)initWithWord:(NSString *)word
                         row:(NSInteger)row
                         col:(NSInteger)col
                      length:(NSInteger)length
                orientations:(NSInteger)orientations
                       score:(NSInteger)score;
@end

@implementation WBWordHit

- (instancetype)initWithWord:(NSString *)word
                         row:(NSInteger)row
                         col:(NSInteger)col
                      length:(NSInteger)length
                orientations:(NSInteger)orientations
                       score:(NSInteger)score {
    self = [super init];
    if (self) {
        _word = [word copy];
        _row = row;
        _col = col;
        _length = length;
        _orientations = orientations;
        _score = score;
    }
    return self;
}

@end

@implementation WBEngine {
    std::unique_ptr<wb::Solver> _solver;
    const wh::Trie *_trieRef;
}

+ (instancetype)sharedEngine {
    static WBEngine *engine;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ engine = [[WBEngine alloc] initPrivate]; });
    return engine;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _trieRef = nullptr;
    }
    return self;
}

- (instancetype)init {
    return [WBEngine sharedEngine];
}

- (NSInteger)gridCols { return wb::kCols; }
- (NSInteger)gridRows { return wb::kRows; }
- (NSInteger)blockCount { return wb::kBlockCount; }

- (void)ensureSolver {
    if (_solver) return;
    const wh::Trie *trie = [[WHWordHuntEngine sharedEngine] trieHandle];
    if (trie == nullptr || trie->empty()) return;
    _trieRef = trie;
    _solver = std::make_unique<wb::Solver>(*_trieRef);
}

- (NSArray<WBBlockInfo *> *)dealBlocksWithSeed:(uint64_t)seed {
    std::vector<wb::Block> blocks = wb::dealAndPlace(seed);
    NSMutableArray<WBBlockInfo *> *result = [NSMutableArray arrayWithCapacity:blocks.size()];
    for (const wb::Block &b : blocks) {
        [result addObject:[[WBBlockInfo alloc] initWithBlock:b]];
    }
    return result;
}

- (NSArray<WBBlockInfo *> *)dealGoodBlocksWithSeed:(uint64_t)seed {
    [self ensureSolver];
    if (_trieRef == nullptr) {
        // Trie not loaded — degrade to random deal so the game still starts.
        return [self dealBlocksWithSeed:seed];
    }
    wb::GoodBlocksResult result = wb::generateGoodBlocks(seed, *_trieRef);
    NSMutableArray<WBBlockInfo *> *out = [NSMutableArray arrayWithCapacity:result.blocks.size()];
    for (const wb::Block &b : result.blocks) {
        [out addObject:[[WBBlockInfo alloc] initWithBlock:b]];
    }
    return out;
}

- (NSArray<WBWordHit *> *)convertHits:(const std::vector<wb::WordHit> &)hits {
    if (_trieRef == nullptr) return @[];
    NSMutableArray<WBWordHit *> *out = [NSMutableArray arrayWithCapacity:hits.size()];
    for (const wb::WordHit &h : hits) {
        const std::string &w = _trieRef->word(h.wordID);
        NSString *word = [[NSString alloc] initWithBytes:w.data() length:w.size() encoding:NSASCIIStringEncoding];
        [out addObject:[[WBWordHit alloc] initWithWord:word
                                                   row:h.row
                                                   col:h.col
                                                length:h.length
                                          orientations:h.orientations
                                                 score:h.score]];
    }
    return out;
}

- (NSArray<WBWordHit *> *)findWordsInGrid:(NSString *)flatGrid {
    [self ensureSolver];
    if (!_solver) return @[];
    wb::Grid grid;
    if (!gridFromString(flatGrid, grid)) return @[];
    auto hits = _solver->findWords(grid);
    return [self convertHits:hits];
}

- (NSArray<WBWordHit *> *)findWordsAffectedByGrid:(NSString *)flatGrid
                                              row:(NSInteger)row
                                              col:(NSInteger)col
                                            shape:(WBShape)shape {
    [self ensureSolver];
    if (!_solver) return @[];
    wb::Grid grid;
    if (!gridFromString(flatGrid, grid)) return @[];
    auto hits = _solver->findWordsAffectedBy(grid,
                                             static_cast<int8_t>(row),
                                             static_cast<int8_t>(col),
                                             shapeToCpp(shape));
    return [self convertHits:hits];
}

- (NSInteger)scoreForLength:(NSInteger)length {
    if (length < 0) return 0;
    return wh::scoreForLength(static_cast<std::size_t>(length));
}

@end
