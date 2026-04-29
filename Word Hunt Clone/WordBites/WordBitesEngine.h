#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WBShape) {
    WBShapeSingle = 0,
    WBShapeHorizontal = 1,
    WBShapeVertical = 2,
};

@interface WBBlockInfo : NSObject

@property (nonatomic, readonly) WBShape shape;
@property (nonatomic, readonly) NSString *letterA;
@property (nonatomic, readonly) NSString *letterB; // empty for singles
@property (nonatomic, readonly) NSInteger row;
@property (nonatomic, readonly) NSInteger col;
@property (nonatomic, readonly) BOOL inTray;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface WBWordHit : NSObject

@property (nonatomic, readonly) NSString *word;
@property (nonatomic, readonly) NSInteger row;
@property (nonatomic, readonly) NSInteger col;
@property (nonatomic, readonly) NSInteger length;
@property (nonatomic, readonly) NSInteger orientations; // bit0 = H, bit1 = V
@property (nonatomic, readonly) NSInteger score;

- (instancetype)init NS_UNAVAILABLE;

@end

@interface WBEngine : NSObject

@property (nonatomic, readonly) NSInteger gridCols;
@property (nonatomic, readonly) NSInteger gridRows;
@property (nonatomic, readonly) NSInteger blockCount;

+ (instancetype)sharedEngine NS_SWIFT_NAME(shared());

- (NSArray<WBBlockInfo *> *)dealBlocksWithSeed:(uint64_t)seed NS_SWIFT_NAME(dealBlocks(seed:));

// flatGrid: NSString of cols*rows characters, 'A'..'Z' or ' ' for empty cells.
- (NSArray<WBWordHit *> *)findWordsInGrid:(NSString *)flatGrid NS_SWIFT_NAME(findWords(grid:));

- (NSArray<WBWordHit *> *)findWordsAffectedByGrid:(NSString *)flatGrid
                                              row:(NSInteger)row
                                              col:(NSInteger)col
                                            shape:(WBShape)shape
    NS_SWIFT_NAME(findWordsAffected(grid:row:col:shape:));

- (NSInteger)scoreForLength:(NSInteger)length NS_SWIFT_NAME(score(length:));

@end

NS_ASSUME_NONNULL_END
