import Foundation

/// Rupee amounts as people type them in chat, and the way they are conventionally written.
///
/// `500 rs`, `rs 500`, `500/-`, `15000 rupaye`, `2 lakh rupees` and `5k rs` all mean rupees,
/// and become `₹500`, `₹15,000`, `₹2,00,000` and `₹5,000`, grouped the Indian way.
/// `lakh` and `crore` almost always mean money in a message, so `1.5 lakh` becomes `₹1,50,000`
/// without a currency word. A bare number never does: it may be a phone number, a year or a code.
public enum RupeeAmount {
    public struct Match: Equatable, Sendable {
        /// The end of the text that the amount replaces, including one trailing space if there was one.
        public let replacing: String
        public let formatted: String
    }

    private static let pattern: NSRegularExpression = {
        let currencyBefore = #"(₹|rs\.?|inr)"#
        let number = #"([0-9]{1,3}(?:,[0-9]{2,3})+|[0-9]+)(?:\.([0-9]+))?"#
        let scale = #"(k|thousand|hazaar|hazar|hajar|lakhs?|lacs?|crores?|cr)"#
        // No full stop after a trailing "rs": there it usually ends the sentence, and must stay.
        let currencyAfter = #"(rs|inr|rupees?|rupaye|rupaiye|rupay|rupiya|rupiye|/-)"#
        let source = #"(?<![\p{L}\p{N}.,])"# + "(?:\(currencyBefore)\\s?)?" + number
            + "(?:\\s?\(scale))?" + "(?:\\s?\(currencyAfter))?" + "( ?)$"
        // The pattern is a constant, so failing to compile it is a programming error.
        return try! NSRegularExpression(pattern: source, options: [.caseInsensitive])
    }()

    private static let lakhCrore: Set<String> = ["lakh", "lakhs", "lac", "lacs", "crore", "crores", "cr"]
    private static let maximumDigits = 15

    /// The rupee amount that `text` ends with, or nil when it does not end with one.
    public static func match(endingAt text: String) -> Match? {
        // Only the last few words can hold the amount, and short input keeps matching fast.
        let tail = String(text.suffix(48))
        let ns = tail as NSString
        guard let m = pattern.firstMatch(in: tail, range: NSRange(location: 0, length: ns.length)) else { return nil }
        func group(_ i: Int) -> String? {
            let r = m.range(at: i)
            return r.location == NSNotFound ? nil : ns.substring(with: r).lowercased()
        }
        let scale = group(4)
        let hasCurrency = group(1) != nil || group(5) != nil
        guard hasCurrency || scale.map(lakhCrore.contains) == true,
              let whole = group(2)?.replacingOccurrences(of: ",", with: ""),
              let value = amount(whole: whole, fraction: group(3), scale: scale),
              let formatted = format(value) else { return nil }
        let replacing = ns.substring(with: m.range)
        // Already written this way.
        guard formatted != replacing.trimmingCharacters(in: .whitespaces) else { return nil }
        return Match(replacing: replacing, formatted: formatted)
    }

    private static func amount(whole: String, fraction: String?, scale: String?) -> Decimal? {
        guard !whole.isEmpty, whole.count <= maximumDigits,
              var value = Decimal(string: fraction.map { "\(whole).\($0)" } ?? whole, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        switch scale {
        case "k", "thousand", "hazaar", "hazar", "hajar": value *= 1_000
        case "lakh", "lakhs", "lac", "lacs": value *= 100_000
        case "crore", "crores", "cr": value *= 10_000_000
        default: break
        }
        return value > 0 ? value : nil
    }

    /// `₹1,50,000`, and paise only when there are any: `₹1,500.50`.
    static func format(_ value: Decimal) -> String? {
        var rounded = Decimal()
        var input = value
        NSDecimalRound(&rounded, &input, 2, .plain)
        let handler = NSDecimalNumberHandler(roundingMode: .down, scale: 0, raiseOnExactness: false,
                                             raiseOnOverflow: false, raiseOnUnderflow: false, raiseOnDivideByZero: false)
        let wholePart = NSDecimalNumber(decimal: rounded).rounding(accordingToBehavior: handler)
        let digits = wholePart.stringValue
        guard digits.count <= maximumDigits, digits.allSatisfy(\.isNumber) else { return nil }
        let paise = (rounded - wholePart.decimalValue) * 100
        let paiseValue = NSDecimalNumber(decimal: paise).intValue
        let grouped = indianGrouping(digits)
        return paiseValue == 0 ? "₹\(grouped)" : "₹\(grouped)." + String(format: "%02d", paiseValue)
    }

    /// Groups digits the Indian way: the last three, then pairs. `1500000` becomes `15,00,000`.
    public static func indianGrouping(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var head = Array(digits.dropLast(3))
        var groups: [String] = [String(digits.suffix(3))]
        while !head.isEmpty {
            groups.insert(String(head.suffix(2)), at: 0)
            head.removeLast(min(2, head.count))
        }
        return groups.joined(separator: ",")
    }
}
