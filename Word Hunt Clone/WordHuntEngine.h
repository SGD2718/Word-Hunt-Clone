#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WHWordResult : NSObject

@property (nonatomic, readonly) NSString *word;
@property (nonatomic, readonly) NSInteger score;
@property (nonatomic, readonly) NSArray<NSNumber *> *path;

- (instancetype)initWithWord:(NSString *)word
                       score:(NSInteger)score
                        path:(NSArray<NSNumber *> *)path NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface WHDictionaryInfo : NSObject

@property (nonatomic, readonly) NSInteger wordCount;
@property (nonatomic, readonly) NSString *sourceURL;
@property (nonatomic, readonly) NSString *sha256;

- (instancetype)initWithWordCount:(NSInteger)wordCount
                        sourceURL:(NSString *)sourceURL
                           sha256:(NSString *)sha256 NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@end

@interface WHWordHuntEngine : NSObject

@property (nonatomic, readonly, getter=isLoaded) BOOL loaded;
@property (nonatomic, readonly, nullable) WHDictionaryInfo *dictionaryInfo;

+ (instancetype)sharedEngine NS_SWIFT_NAME(shared());

- (BOOL)loadBundledDictionaryWithError:(NSError **)error NS_SWIFT_NAME(loadBundledDictionary());
- (void)loadWordsForTesting:(NSArray<NSString *> *)words NS_SWIFT_NAME(loadWordsForTesting(_:));
- (NSArray<NSString *> *)generateBoardWithSeed:(uint64_t)seed NS_SWIFT_NAME(generateBoard(seed:));
- (NSArray<WHWordResult *> *)solveBoard:(NSArray<NSString *> *)board NS_SWIFT_NAME(solve(board:));
- (BOOL)isValidPathForBoard:(NSArray<NSString *> *)board path:(NSArray<NSNumber *> *)path NS_SWIFT_NAME(isValidPath(board:path:));
- (BOOL)containsWord:(NSString *)word NS_SWIFT_NAME(contains(word:));
- (NSString *)wordForBoard:(NSArray<NSString *> *)board path:(NSArray<NSNumber *> *)path NS_SWIFT_NAME(word(board:path:));
- (NSInteger)scoreForWord:(NSString *)word NS_SWIFT_NAME(score(word:));

@end

NS_ASSUME_NONNULL_END
