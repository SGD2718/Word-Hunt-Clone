#include "WHScoring.hpp"

namespace wh {

int scoreForLength(std::size_t length) {
    switch (length) {
        case 3: return 100;
        case 4: return 400;
        case 5: return 800;
        case 6: return 1400;
        case 7: return 1800;
        default: return length >= 8 ? 2200 : 0;
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
