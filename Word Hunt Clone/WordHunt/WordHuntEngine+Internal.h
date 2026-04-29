#import "WordHuntEngine.h"

#ifdef __cplusplus
#include "WHTrie.hpp"

@interface WHWordHuntEngine (Internal)
- (const wh::Trie *)trieHandle;
@end
#endif
