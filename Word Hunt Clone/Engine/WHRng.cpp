#include "WHRng.hpp"

namespace wh {

SplitMix64::SplitMix64(uint64_t seed) : state_(seed) {}

uint64_t SplitMix64::next() {
    uint64_t z = (state_ += 0x9E3779B97F4A7C15ULL);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
}

Xoshiro256StarStar::Xoshiro256StarStar(uint64_t seed) {
    SplitMix64 split(seed);
    for (uint64_t &value : state_) {
        value = split.next();
    }
}

uint64_t Xoshiro256StarStar::next() {
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

uint32_t Xoshiro256StarStar::nextBounded(uint32_t upperBound) {
    uint64_t threshold = (0ULL - upperBound) % upperBound;
    while (true) {
        uint64_t value = next();
        if (value >= threshold) {
            return static_cast<uint32_t>(value % upperBound);
        }
    }
}

} // namespace wh
