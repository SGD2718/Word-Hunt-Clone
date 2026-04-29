#pragma once

#include <climits>
#include <cstdint>
#include <string>
#include <vector>

#include "WHScoring.hpp"

namespace wh {

constexpr uint32_t kNoWord = UINT32_MAX;

struct TrieNode {
    uint32_t firstChild = 0;
    uint32_t childMask = 0;
    uint32_t terminal = kNoWord;
};

class Trie {
public:
    void load(std::vector<std::string> inputWords);

    std::size_t wordCount() const { return words_.size(); }
    bool contains(const std::string &word) const;
    int32_t child(uint32_t nodeIndex, uint8_t letter) const;
    const std::string &word(uint32_t id) const { return words_[id]; }

    const std::vector<TrieNode> &nodes() const { return nodes_; }
    bool empty() const { return nodes_.empty() || words_.empty(); }

private:
    std::vector<TrieNode> nodes_;
    std::vector<uint32_t> children_;
    std::vector<std::string> words_;
};

} // namespace wh
