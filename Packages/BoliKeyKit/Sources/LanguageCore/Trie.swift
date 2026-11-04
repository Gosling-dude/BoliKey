import Foundation

/// A compact trie over UTF-8 bytes. Children live in one contiguous array per node,
/// sorted by byte, which keeps memory low enough for a keyboard extension.
public final class Trie {
    private struct Node {
        var firstChild: Int32 = -1
        var sibling: Int32 = -1
        var byte: UInt8 = 0
        var wordIndex: Int32 = -1
        /// The best word frequency in this subtree, which prunes completion search.
        var best: Float = 0
    }

    private var nodes: [Node] = [Node()]
    public private(set) var words: [String] = []
    private var scores: [Float] = []

    public init() {}

    public var count: Int { words.count }

    public func reserve(_ capacity: Int) {
        nodes.reserveCapacity(capacity * 4)
        words.reserveCapacity(capacity)
        scores.reserveCapacity(capacity)
    }

    public func insert(_ word: String, score: Float) {
        var cur = 0
        for byte in word.utf8 {
            nodes[cur].best = max(nodes[cur].best, score)
            cur = child(of: cur, byte: byte, create: true)
        }
        nodes[cur].best = max(nodes[cur].best, score)
        if nodes[cur].wordIndex >= 0 {
            scores[Int(nodes[cur].wordIndex)] = max(scores[Int(nodes[cur].wordIndex)], score)
        } else {
            nodes[cur].wordIndex = Int32(words.count)
            words.append(word)
            scores.append(score)
        }
    }

    private func child(of parent: Int, byte: UInt8, create: Bool) -> Int {
        var c = Int(nodes[parent].firstChild)
        while c >= 0 {
            if nodes[c].byte == byte { return c }
            c = Int(nodes[c].sibling)
        }
        guard create else { return -1 }
        var n = Node()
        n.byte = byte
        n.sibling = nodes[parent].firstChild
        nodes.append(n)
        let idx = nodes.count - 1
        nodes[parent].firstChild = Int32(idx)
        return idx
    }

    public func contains(_ word: String) -> Bool {
        guard let node = locate(word) else { return false }
        return nodes[node].wordIndex >= 0
    }

    private func locate(_ prefix: String) -> Int? {
        var cur = 0
        for byte in prefix.utf8 {
            cur = child(of: cur, byte: byte, create: false)
            if cur < 0 { return nil }
        }
        return cur
    }

    /// Top-scoring words under `prefix`. Branch-and-bound on subtree best scores.
    public func completions(of prefix: String, limit: Int) -> [(word: String, score: Float)] {
        guard let start = locate(prefix), limit > 0 else { return [] }
        var results: [(word: String, score: Float)] = []
        var stack = [start]
        while let cur = stack.popLast() {
            if results.count >= limit, let worst = results.last?.score, nodes[cur].best <= worst { continue }
            let wi = nodes[cur].wordIndex
            if wi >= 0 {
                let entry = (word: words[Int(wi)], score: scores[Int(wi)])
                let at = results.firstIndex { $0.score < entry.score } ?? results.count
                results.insert(entry, at: at)
                if results.count > limit { results.removeLast() }
            }
            var c = Int(nodes[cur].firstChild)
            while c >= 0 {
                stack.append(c)
                c = Int(nodes[c].sibling)
            }
        }
        return results
    }

    public struct FuzzyMatch {
        public let word: String
        public let score: Float
        public let cost: Float
    }

    /// Bounded weighted edit-distance search, walking the trie with a Damerau-Levenshtein row per node.
    public func fuzzySearch(_ query: String, maxCost: Float, cost model: EditCostModel) -> [FuzzyMatch] {
        let q = Array(query.utf8)
        guard !q.isEmpty else { return [] }
        let first = (0...q.count).map { Float($0) * model.insertion }
        var results: [FuzzyMatch] = []

        func walk(_ node: Int, _ parentByte: UInt8, _ prevRow: [Float], _ prevPrevRow: [Float]?, _ grandByte: UInt8) {
            var c = Int(nodes[node].firstChild)
            while c >= 0 {
                let byte = nodes[c].byte
                var row = [Float](repeating: 0, count: q.count + 1)
                row[0] = prevRow[0] + model.deletion
                var best = row[0]
                for i in 1...q.count {
                    let sub = prevRow[i - 1] + (q[i - 1] == byte ? 0 : model.substitution(q[i - 1], byte))
                    var v = min(sub, min(prevRow[i] + model.omitted(byte), row[i - 1] + model.extra(q[i - 1], i >= 2 ? q[i - 2] : nil)))
                    if let pp = prevPrevRow, i >= 2, q[i - 1] == parentByte, q[i - 2] == byte {
                        v = min(v, pp[i - 2] + model.transposition)
                    }
                    row[i] = v
                    best = min(best, v)
                }
                if nodes[c].wordIndex >= 0, row[q.count] <= maxCost {
                    let wi = Int(nodes[c].wordIndex)
                    results.append(FuzzyMatch(word: words[wi], score: scores[wi], cost: row[q.count]))
                }
                if best <= maxCost {
                    walk(c, byte, row, prevRow, parentByte)
                }
                c = Int(nodes[c].sibling)
            }
        }
        walk(0, 0, first, nil, 0)
        return results
    }
}

/// Edit costs for the fuzzy search. Typing mistakes are not uniform, and this encodes why.
public struct EditCostModel {
    public var insertion: Float = 1
    public var deletion: Float = 1
    public var transposition: Float = 0.55

    public init() {}

    private static let adjacency: [UInt8: Set<UInt8>] = {
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"].map { Array($0.utf8) }
        var map: [UInt8: Set<UInt8>] = [:]
        for (r, row) in rows.enumerated() {
            for (c, key) in row.enumerated() {
                var near = Set<UInt8>()
                if c > 0 { near.insert(row[c - 1]) }
                if c + 1 < row.count { near.insert(row[c + 1]) }
                if r + 1 < rows.count {
                    for d in [c - 1, c, c + 1] where d >= 0 && d < rows[r + 1].count { near.insert(rows[r + 1][d]) }
                }
                if r > 0 {
                    for d in [c, c + 1] where d >= 0 && d < rows[r - 1].count { near.insert(rows[r - 1][d]) }
                }
                map[key] = near
            }
        }
        return map
    }()

    private static let vowels = Set("aeiou".utf8)

    func substitution(_ a: UInt8, _ b: UInt8) -> Float {
        if Self.adjacency[a]?.contains(b) == true { return 0.6 }
        if Self.vowels.contains(a), Self.vowels.contains(b) { return 0.75 }
        return 1.1
    }

    /// The typed word lacks `byte`. Omitted vowels are common and cheap.
    func omitted(_ byte: UInt8) -> Float { Self.vowels.contains(byte) ? 0.7 : deletion }

    /// The typed word has an extra character. Doubling the previous letter is cheapest.
    func extra(_ byte: UInt8, _ previous: UInt8?) -> Float { byte == previous ? 0.4 : insertion }
}
