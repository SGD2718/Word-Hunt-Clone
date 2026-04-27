#pragma once

#include <array>
#include <cstdint>

namespace wh {

class SplitMix64 {
public:
    explicit SplitMix64(uint64_t seed);
    uint64_t next();

private:
    uint64_t state_;
};

class Xoshiro256StarStar {
public:
    explicit Xoshiro256StarStar(uint64_t seed);
    uint64_t next();
    uint32_t nextBounded(uint32_t upperBound);

private:
    static uint64_t rotl(uint64_t value, int shift) {
        return (value << shift) | (value >> (64 - shift));
    }

    std::array<uint64_t, 4> state_{};
};

} // namespace wh
