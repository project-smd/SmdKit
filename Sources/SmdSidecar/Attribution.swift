// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import SmdKit

/// Whose a field of the container, or a kind of its artwork, is: the provider it came from and the
/// reference it came from there. A library fact, as a presentation is — the repository document has
/// no place for it, since what a provider's contributors wrote is not the database's to hold — so
/// that a player can credit it and an export can leave it out.
public struct Attribution: Hashable, Sendable, Codable {
    public var subject: Subject
    public var provider: Provider
    public var value: String

    public init(subject: Subject, provider: Provider, value: String) {
        self.subject = subject
        self.provider = provider
        self.value = value
    }

    /// What is attributed, as the `subject` attribute spells it: `outline`, an alternative's outline
    /// as `alternative/<id>/outline`, or an artwork kind as `artwork/<kind>`. Read as written, so a
    /// subject none of these describes reaches whoever checks the sidecar rather than making it
    /// unreadable.
    public struct Subject: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
        public let rawValue: String

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public static let outline = Subject(rawValue: "outline")

        public static func outline(ofAlternative id: String) -> Subject {
            Subject(rawValue: "alternative/\(id)/outline")
        }

        public static func artwork(_ kind: String) -> Subject {
            Subject(rawValue: "artwork/\(kind)")
        }

        /// The alternative whose outline this is, for an alternative's outline.
        public var alternative: String? {
            let parts = rawValue.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 3, parts[0] == "alternative", parts[2] == "outline", !parts[1].isEmpty else {
                return nil
            }
            return String(parts[1])
        }

        /// The artwork kind, for an artwork kind's attribution.
        public var artworkKind: String? {
            guard rawValue.hasPrefix("artwork/") else { return nil }
            let kind = rawValue.dropFirst("artwork/".count)
            return kind.isEmpty || kind.contains("/") ? nil : String(kind)
        }

        /// Whether this names a field of the container's own: its outline or an alternative's.
        public var isField: Bool {
            self == .outline || alternative != nil
        }

        public var description: String { rawValue }
    }
}
