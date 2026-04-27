#include "WHTrie.hpp"

#include <algorithm>
#include <array>

namespace wh {

namespace {

struct TempNode {
    std::array<int32_t, 26> children;
    uint32_t terminal = kNoWord;

    TempNode() {
        children.fill(-1);
    }
};

} // namespace

void Trie::load(std::vector<std::string> inputWords) {
    std::sort(inputWords.begin(), inputWords.end());
    inputWords.erase(std::unique(inputWords.begin(), inputWords.end()), inputWords.end());

    words_.clear();
    words_.reserve(inputWords.size());
    std::vector<TempNode> temp(1);

    for (const std::string &word : inputWords) {
        if (word.size() < static_cast<std::size_t>(kMinWordLength) ||
            word.size() > static_cast<std::size_t>(kBoardSize)) {
            continue;
        }

        uint32_t node = 0;
        bool valid = true;
        for (char c : word) {
            if (c < 'A' || c > 'Z') {
                valid = false;
                break;
            }
            int letter = c - 'A';
            int32_t childIndex = temp[node].children[letter];
            if (childIndex < 0) {
                childIndex = static_cast<int32_t>(temp.size());
                temp[node].children[letter] = childIndex;
                temp.emplace_back();
            }
            node = static_cast<uint32_t>(childIndex);
        }
        if (!valid || temp[node].terminal != kNoWord) {
            continue;
        }
        temp[node].terminal = static_cast<uint32_t>(words_.size());
        words_.push_back(word);
    }

    nodes_.assign(temp.size(), TrieNode{});
    children_.clear();
    children_.reserve(temp.size() * 2);

    for (std::size_t index = 0; index < temp.size(); ++index) {
        TrieNode node;
        node.firstChild = static_cast<uint32_t>(children_.size());
        node.terminal = temp[index].terminal;
        for (int letter = 0; letter < 26; ++letter) {
            int32_t childIndex = temp[index].children[letter];
            if (childIndex >= 0) {
                node.childMask |= (1u << letter);
                children_.push_back(static_cast<uint32_t>(childIndex));
            }
        }
        nodes_[index] = node;
    }
}

bool Trie::contains(const std::string &word) const {
    if (nodes_.empty()) {
        return false;
    }
    uint32_t node = 0;
    for (char c : word) {
        if (c < 'A' || c > 'Z') {
            return false;
        }
        int32_t next = child(node, static_cast<uint8_t>(c - 'A'));
        if (next < 0) {
            return false;
        }
        node = static_cast<uint32_t>(next);
    }
    return nodes_[node].terminal != kNoWord;
}

int32_t Trie::child(uint32_t nodeIndex, uint8_t letter) const {
    const TrieNode &node = nodes_[nodeIndex];
    uint32_t bit = 1u << letter;
    if ((node.childMask & bit) == 0) {
        return -1;
    }
    uint32_t lowerMask = node.childMask & (bit - 1);
    uint32_t offset = static_cast<uint32_t>(__builtin_popcount(lowerMask));
    return static_cast<int32_t>(children_[node.firstChild + offset]);
}

} // namespace wh
