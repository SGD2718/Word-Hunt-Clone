#include "WHScoring.hpp"

namespace wh {

int scoreForLength(std::size_t length) {
    if (length < 3) return 0;
    switch (length) {
        case 3: return 100;
        case 4: return 400;
        case 5: return 800;
        default: return 1400 + 400 * (static_cast<int>(length) - 6);
    }
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
