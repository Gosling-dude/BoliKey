import Foundation

/// Per-language n-gram tables, searched in the mapped file and normalised on demand.
public final class NGramModel {
    public enum Language: Hashable, Sendable { case hinglish, english, devanagari }

    public struct Next: Sendable {
        public let word: String
        public let probability: Float
    }

    private var table: MappedTable?
    /// Line ranges by language and order. Contexts are sorted within each range.
    private var sections: [String: Range<Int>] = [:]

    public init() {}

    func parse(_ data: Data) {
        let table = MappedTable(data: data)
        self.table = table
        // A run of equal "model, order" prefixes forms a section. Finding the boundaries takes
        // one binary search per section, as those prefixes are sorted in the file's written order.
        var start = 0
        while start < table.count {
            let fields = table.fields(at: start)
            guard fields.count == 5 else { break }
            let model = fields[0], order = fields[1]
            var lo = start + 1, hi = table.count
            while lo < hi {
                let mid = (lo + hi) / 2
                let f = table.fields(at: mid)
                if f.first == model, f.count > 1, f[1] == order { lo = mid + 1 } else { hi = mid }
            }
            sections[model + order] = start..<lo
            start = lo
        }
    }

    private func key(_ language: Language, order: Int) -> String {
        switch language {
        case .hinglish: return "h\(order)"
        case .english: return "e\(order)"
        case .devanagari: return "d\(order)"
        }
    }

    private func lookup(_ context: String, section: String) -> [Next] {
        guard let table, let range = sections[section] else { return [] }
        let found = table.equalRange(of: context, skip: 2, in: range)
        guard !found.isEmpty else { return [] }
        var rows: [(String, Int)] = []
        rows.reserveCapacity(found.count)
        var total = 0
        for i in found {
            let f = table.fields(at: i)
            let count = Int(f[4]) ?? 0
            rows.append((f[3], count))
            total += count
        }
        rows.sort { $0.1 > $1.1 }
        return rows.map { Next(word: $0.0, probability: Float($0.1) / Float(max(total, 1))) }
    }

    public func next(after word: String, in language: Language) -> [Next] {
        lookup(word, section: key(language, order: 2))
    }

    public func next(after first: String, _ second: String, in language: Language) -> [Next] {
        lookup("\(first) \(second)", section: key(language, order: 3))
    }
}
