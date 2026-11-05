// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

/// A day of the proleptic Gregorian calendar, written `yyyy-mm-dd`: when a container was first
/// broadcast or released. A day and no more, because that is what a broadcast listing or a release
/// records, and no time zone, since none is known.
///
/// The one initialiser checks the shape and the day, so a date the container file's reader would
/// refuse — the thirtieth of February, a thirteenth month — cannot be built, and decoding one throws.
public struct CalendarDate: Hashable, Sendable, Codable, Comparable, LosslessStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (0...9999).contains(year), (1...12).contains(month), (1...Self.days(in: month, of: year)).contains(day)
        else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The string as a date only when it is one written `yyyy-mm-dd`, digits throughout.
    public init?(_ string: String) {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.map(\.count) == [4, 2, 2],
            parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else {
            return nil
        }
        self.init(year: year, month: month, day: day)
    }

    private static func days(in month: Int, of year: Int) -> Int {
        switch month {
        case 2: year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    public var description: String {
        func padded(_ value: Int, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
        return "\(padded(year, 4))-\(padded(month, 2))-\(padded(day, 2))"
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// A bare string, decoded through the check.
    public init(from decoder: any Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let date = CalendarDate(string) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Not a calendar date: \(string)")
            )
        }
        self = date
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
