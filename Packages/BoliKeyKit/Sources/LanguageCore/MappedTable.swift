import Foundation

/// A sorted tab-separated file, memory-mapped and searched in place.
///
/// Mapped file pages are clean and can be evicted, so they do not count against the tight
/// memory limit iOS gives keyboard extensions. The only heap cost is one offset per line.
final class MappedTable {
    private let data: Data
    private var offsets: [UInt32] = []

    init(data: Data) {
        self.data = data
        offsets.reserveCapacity(data.count / 24)
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return }
            var start = 0
            for i in 0..<raw.count where base[i] == 10 {
                offsets.append(UInt32(start))
                start = i + 1
            }
            if start < raw.count { offsets.append(UInt32(start)) }
        }
        offsets.append(UInt32(data.count))
    }

    var count: Int { offsets.count - 1 }

    /// The tab-separated fields of one line, decoded on demand.
    func fields(at index: Int) -> [String] {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> [String] in
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            let start = Int(offsets[index])
            var end = Int(offsets[index + 1])
            if end > start, base[end - 1] == 10 { end -= 1 }
            var out: [String] = []
            out.reserveCapacity(7)
            var fieldStart = start
            for i in start...end where i == end || base[i] == 9 {
                out.append(String(decoding: UnsafeBufferPointer(start: base + fieldStart, count: i - fieldStart), as: UTF8.self))
                fieldStart = i + 1
            }
            return out
        }
    }

    /// Compares the bytes after `skip` tab-separated fields of a line with `key`, as a whole field.
    /// Lines are sorted by bytes, which the Python builder's code point ordering guarantees.
    private func compare(line index: Int, skip: Int, key: UnsafeBufferPointer<UInt8>) -> Int {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int in
            let base = raw.bindMemory(to: UInt8.self).baseAddress!
            var p = Int(offsets[index])
            let end = Int(offsets[index + 1])
            var skipped = 0
            while skipped < skip, p < end {
                if base[p] == 9 { skipped += 1 }
                p += 1
            }
            var k = 0
            while k < key.count, p < end, base[p] != 9, base[p] != 10 {
                if base[p] != key[k] { return base[p] < key[k] ? -1 : 1 }
                p += 1
                k += 1
            }
            let lineEnded = p >= end || base[p] == 9 || base[p] == 10
            if k == key.count { return lineEnded ? 0 : 1 }
            return -1
        }
    }

    /// The half-open range of lines in `range` whose field number `skip` equals `key`.
    func equalRange(of key: String, skip: Int = 0, in range: Range<Int>? = nil) -> Range<Int> {
        var key = key
        return key.withUTF8 { keyBytes -> Range<Int> in
            let full = range ?? 0..<count
            var lo = full.lowerBound, hi = full.upperBound
            while lo < hi {
                let mid = (lo + hi) / 2
                if compare(line: mid, skip: skip, key: keyBytes) < 0 { lo = mid + 1 } else { hi = mid }
            }
            let start = lo
            hi = full.upperBound
            while lo < hi {
                let mid = (lo + hi) / 2
                if compare(line: mid, skip: skip, key: keyBytes) <= 0 { lo = mid + 1 } else { hi = mid }
            }
            return start..<lo
        }
    }
}
