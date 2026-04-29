#include "WHScoring.hpp"

namespace wh {

int scoreForLength(std::size_t length) {
    if (length < 3) return 0;
    auto length32 = static_cast<int>(length);
    return std::max(100, 400 * (length32 - 3) + 200 * (length32 >= 6));
}

bool normalizeAscii(const char *utf8, std::string &out) {
    out.clear();
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

} // namespace wh
