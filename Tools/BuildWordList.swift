import CryptoKit
import Foundation

struct Manifest: Encodable {
    let sourceURL: String
    let generatedAt: String
    let rawSHA256: String
    let sha256: String
    let wordCount: Int
    let minLength: Int
    let maxLength: Int
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard (4...5).contains(arguments.count) else {
    fail("Usage: BuildWordList <input txt> <output whdict> <output manifest json> [source url]")
}

let inputURL = URL(fileURLWithPath: arguments[1])
let dictionaryURL = URL(fileURLWithPath: arguments[2])
let manifestURL = URL(fileURLWithPath: arguments[3])
let sourceURL = arguments.count == 5
    ? arguments[4]
    : "https://github.com/Ammaar-Alam/wordhunt-solver/blob/main/dictionary.txt"

let rawData = try Data(contentsOf: inputURL)
guard let rawText = String(data: rawData, encoding: .utf8) else {
    fail("Input is not UTF-8: \(inputURL.path)")
}

let words = rawText
    .split(whereSeparator: \.isNewline)
    .compactMap { line -> String? in
        let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.split(whereSeparator: \.isWhitespace).first.map { String($0).uppercased() }
    }
    .filter { word in
        guard (3...16).contains(word.count) else { return false }
        return word.utf8.allSatisfy { byte in byte >= 65 && byte <= 90 }
    }

let uniqueWords = Array(Set(words)).sorted()

var dictionary = Data()
dictionary.append(contentsOf: Array("WHNWL23".utf8))
dictionary.append(0)
var count = UInt32(uniqueWords.count).littleEndian
withUnsafeBytes(of: &count) { dictionary.append(contentsOf: $0) }

for word in uniqueWords {
    let bytes = Array(word.utf8)
    dictionary.append(UInt8(bytes.count))
    dictionary.append(contentsOf: bytes)
}

try FileManager.default.createDirectory(at: dictionaryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try dictionary.write(to: dictionaryURL, options: .atomic)

let rawSHA = SHA256.hash(data: rawData).map { String(format: "%02x", $0) }.joined()
let generatedSHA = SHA256.hash(data: dictionary).map { String(format: "%02x", $0) }.joined()
let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime]

let manifest = Manifest(
    sourceURL: sourceURL,
    generatedAt: formatter.string(from: Date()),
    rawSHA256: rawSHA,
    sha256: generatedSHA,
    wordCount: uniqueWords.count,
    minLength: uniqueWords.map(\.count).min() ?? 0,
    maxLength: uniqueWords.map(\.count).max() ?? 0
)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(manifest).write(to: manifestURL, options: .atomic)

print("Wrote \(uniqueWords.count) words to \(dictionaryURL.path)")
