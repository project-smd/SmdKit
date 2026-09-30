// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2026 the smddb project authors

import Foundation

/// The identity of a container in the database: minted once, when the container is created, and
/// never reissued. Sixteen lowercase hex characters, 64 random bits, as `ContainerDatabase.md`
/// specifies: minted without coordination, as a clone of the data repository has to, and short
/// enough to read in a ref or a file listing. Readability in a review comes from the file's title,
/// not its name.
///
/// The one initialiser checks the shape, so an id that the container file's reader would refuse
/// cannot be built, and decoding one throws.
public struct ContainerID: Hashable, Sendable, Codable, LosslessStringConvertible {
    public let value: String

    /// The string as an id, or nil when it is not one: the shape is checked, not the provenance,
    /// so an id minted by any tool that draws sixteen hex characters is accepted.
    public init?(_ string: String) {
        guard string.count == 16, string.unicodeScalars.allSatisfy({ ($0.value >= 0x30 && $0.value <= 0x39) || ($0.value >= 0x61 && $0.value <= 0x66) }) else {
            return nil
        }
        value = string
    }

    private init(minted: String) {
        value = minted
    }

    public static func mint() -> ContainerID {
        ContainerID(minted: String(format: "%016llx", UInt64.random(in: .min ... .max)))
    }

    public var description: String { value }

    /// A bare string, decoded through the check, so a malformed id cannot arrive as JSON either.
    public init(from decoder: any Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let id = ContainerID(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a container id: \(string)"))
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// The id of an entry, unique within its container, and what a ref names. Non-empty, and free of
/// the characters that would not come back from the file as written: `#`, which separates the
/// container from the item in a ref into another container; tab and the line breaks, which the
/// writer turns into spaces in an attribute; and anything XML 1.0 cannot carry at all.
public struct ItemID: Hashable, Sendable, Codable, LosslessStringConvertible {
    public let value: String

    public init?(_ string: String) {
        guard !string.isEmpty, string.unicodeScalars.allSatisfy({
            XMLText.carries($0) && $0 != "#" && $0 != "\t" && $0 != "\n" && $0 != "\r"
        }) else {
            return nil
        }
        value = string
    }

    public var description: String { value }

    /// A bare string, decoded through the check.
    public init(from decoder: any Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let id = ItemID(string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an item id: \(string)"))
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

/// A container's title: never empty, and without whitespace at either end, because the file's
/// reader trims it and a title must read back as it was written.
public struct Title: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    /// The string as a title only when it already is one: trimmed, non-empty, and carried by XML.
    /// Decoding goes through this, so text a title would have to change to hold is refused.
    public init?(rawValue: String) {
        guard !rawValue.isEmpty,
              rawValue.trimmingCharacters(in: .whitespacesAndNewlines) == rawValue,
              rawValue.unicodeScalars.allSatisfy(XMLText.carries)
        else {
            return nil
        }
        self.rawValue = rawValue
    }

    /// The string, trimmed, as a title; nil when nothing is left or XML cannot carry it.
    public init?(_ string: String) {
        self.init(rawValue: string.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public var description: String { rawValue }
}

/// What XML 1.0 can carry: its `Char` production. Anything else cannot be written in a document,
/// escaped or not, and a document holding it is not well-formed.
enum XMLText {
    static func carries(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x9, 0xA, 0xD, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
        default: false
        }
    }

    /// Text as the writer writes it: without the characters XML 1.0 cannot carry, and with a
    /// carriage return, alone or before a line feed, as a line feed.
    ///
    /// The writer folds line ends before it writes, so the file holds the value as it reads back.
    /// It began as the answer to the platforms' serialisers disagreeing — Darwin wrote a carriage
    /// return as itself, which the reader folds, and Linux as a character reference, which
    /// survives — and stays as the round trip the container-file spec states.
    static func text(_ string: String) -> String {
        guard string.unicodeScalars.contains(where: { !carries($0) || $0 == "\r" }) else { return string }
        var result = String.UnicodeScalarView()
        var afterReturn = false
        for scalar in string.unicodeScalars where carries(scalar) {
            if scalar == "\r" {
                result.append("\n")
            } else if !(scalar == "\n" && afterReturn) {
                result.append(scalar)
            }
            afterReturn = scalar == "\r"
        }
        return String(result)
    }

    /// An attribute value as the writer writes it: as `text(_:)`, then with each tab and line
    /// feed as a space, which is what the reader's attribute normalisation would make of them.
    static func attribute(_ string: String) -> String {
        let text = text(string)
        guard text.unicodeScalars.contains(where: { $0 == "\t" || $0 == "\n" }) else { return text }
        var result = String.UnicodeScalarView()
        result.append(contentsOf: text.unicodeScalars.map { $0 == "\t" || $0 == "\n" ? " " : $0 })
        return String(result)
    }
}

/// What a container is, from the sidecar's `type` attribute. The label shown for it is separate
/// (`Container.typeLabel`): a serial is called a story by one show and a serial by another.
public enum ContainerType: String, CaseIterable, Sendable, Codable {
    case series, season, serial, arc, volume, collection, episode, movie

    public var title: String {
        switch self {
        case .series: "Series"
        case .season: "Season"
        case .serial: "Serial"
        case .arc: "Arc"
        case .volume: "Volume"
        case .collection: "Collection"
        case .episode: "Episode"
        case .movie: "Movie"
        }
    }

    /// Whether a container of this type has a year of its own: a series began in one, a season
    /// aired in one, a film was released in one. A serial or an episode takes its year from the
    /// season it is in, and a collection has none.
    public var hasYear: Bool {
        switch self {
        case .series, .season, .movie: true
        case .serial, .arc, .volume, .collection, .episode: false
        }
    }
}

/// Who else knows this thing, and by what name. Providers are open-ended — a new one is a string,
/// not a code change — with the ones the proposals name given here so they are spelled once.
public struct Provider: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let tvdb = Provider(rawValue: "tvdb")
    public static let tmdb = Provider(rawValue: "tmdb")
    public static let imdb = Provider(rawValue: "imdb")
    public static let wikidata = Provider(rawValue: "wikidata")
    public static let thediscdb = Provider(rawValue: "thediscdb")
    public static let upc = Provider(rawValue: "upc")
    public static let asin = Provider(rawValue: "asin")

    /// The ones a container or an entry is usually identified by, in the order a picker lists them.
    public static let known: [Provider] = [.tvdb, .tmdb, .imdb, .wikidata]

    public var title: String {
        switch self {
        case .tvdb: "TVDB"
        case .tmdb: "TMDb"
        case .imdb: "IMDb"
        case .wikidata: "Wikidata"
        case .thediscdb: "TheDiscDb"
        case .upc: "UPC"
        case .asin: "ASIN"
        default: rawValue
        }
    }

    public var description: String { rawValue }
}

public struct ExternalRef: Hashable, Sendable, Codable {
    public var provider: Provider
    public var value: String

    public init(provider: Provider, value: String) {
        self.provider = provider
        self.value = value
    }
}

/// One container, as the database keeps it: the sidecar's `<container>` with everything a library
/// adds — file paths and presentations — taken out, and what the database adds — external
/// references, and children named by identity rather than by path — put in.
public struct Container: Identifiable, Hashable, Sendable {
    public var id: ContainerID
    public var type: ContainerType
    /// What to call the type: "Story", "Season", "Volume". Nil means the type's own name.
    public var typeLabel: String?
    public var title: Title
    /// The year a series began, a season aired or a film was released, for the types that have
    /// one (`ContainerType.hasYear`). Nil elsewhere.
    public var year: Int?
    /// Whether the year is part of how the container is named — "Doctor Who (1963)" against
    /// "Doctor Who" — as a library folder or a listing shows it. See `displayTitle`.
    public var yearInTitle: Bool
    public var outline: String?
    /// False for a companion series nobody browses to directly: reachable through a relation or a
    /// ref, and nowhere else.
    public var listed: Bool
    public var externalRefs: [ExternalRef]
    /// Which alternative a client plays when it has not been asked; the id of one in `alternatives`.
    public var defaultAlternative: String?
    public var alternatives: [Alternative]
    public var features: [Feature]
    public var sequences: [Sequence]
    /// The item in the sequences the extras hang off, when they hang off one.
    public var extrasAnchor: String?
    public var extras: [Entry]

    public init(
        id: ContainerID = .mint(),
        type: ContainerType,
        typeLabel: String? = nil,
        title: Title,
        year: Int? = nil,
        yearInTitle: Bool = false,
        outline: String? = nil,
        listed: Bool = true,
        externalRefs: [ExternalRef] = [],
        defaultAlternative: String? = nil,
        alternatives: [Alternative] = [],
        features: [Feature] = [],
        sequences: [Sequence] = [],
        extrasAnchor: String? = nil,
        extras: [Entry] = []
    ) {
        self.id = id
        self.type = type
        self.typeLabel = typeLabel
        self.title = title
        self.year = year
        self.yearInTitle = yearInTitle
        self.outline = outline
        self.listed = listed
        self.externalRefs = externalRefs
        self.defaultAlternative = defaultAlternative
        self.alternatives = alternatives
        self.features = features
        self.sequences = sequences
        self.extrasAnchor = extrasAnchor
        self.extras = extras
    }

    /// The title with the year after it when `yearInTitle` says so and there is one.
    public var displayTitle: String {
        if yearInTitle, let year { "\(title) (\(year))" } else { title.rawValue }
    }

    /// The containers this one holds, in the order its sequences and extras list them.
    public var childContainerIDs: [ContainerID] {
        (sequences.flatMap(\.items) + extras).compactMap {
            if case .child(let child) = $0 { child.container } else { nil }
        }
    }

    /// Every item id declared here, sequences and extras together. Refs declare none.
    public var itemIDs: Set<ItemID> {
        Set((sequences.flatMap(\.items) + extras).compactMap(\.id))
    }
}

/// A cut of the container: which sequence it plays, and what to call it.
public struct Alternative: Identifiable, Hashable, Sendable {
    public var id: String
    public var sequence: String
    public var title: String?
    public var outline: String?

    public init(id: String, sequence: String, title: String? = nil, outline: String? = nil) {
        self.id = id
        self.sequence = sequence
        self.title = title
        self.outline = outline
    }
}

/// Something an item can carry a track of: a commentary, an isolated score. Declared once, on the
/// container that owns it, and referenced by the items that have it.
public struct Feature: Identifiable, Hashable, Sendable {
    public var id: String
    public var type: FeatureType
    public var title: String?
    public var participants: [Participant]

    public init(id: String, type: FeatureType, title: String? = nil, participants: [Participant] = []) {
        self.id = id
        self.type = type
        self.title = title
        self.participants = participants
    }
}

public struct FeatureType: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let commentary = FeatureType(rawValue: "commentary")
    public static let isolatedMusic = FeatureType(rawValue: "isolatedMusic")

    public var description: String { rawValue }
}

public struct Participant: Hashable, Sendable {
    public var name: String
    public var role: String?

    public init(name: String, role: String? = nil) {
        self.name = name
        self.role = role
    }
}

/// An ordered run of items: the broadcast parts, the omnibus, a DVD order. A container with one
/// order of things has one sequence, and it need not be named.
public struct Sequence: Hashable, Sendable {
    public var id: String?
    public var exploded: Exploded
    public var items: [Entry]

    public init(id: String? = nil, exploded: Exploded = .never, items: [Entry] = []) {
        self.id = id
        self.exploded = exploded
        self.items = items
    }
}

/// Whether a client may show the sequence's items as if they were the container's parent's.
public enum Exploded: String, CaseIterable, Sendable, Codable {
    case never, allowed, preferred
}

/// The sidecar's `<item>`, one case per kind, each carrying only the fields that kind has: so a
/// child always names a container, a leaf never does, and a ref has no id of its own.
public enum Entry: Hashable, Sendable {
    /// An episode, a film, a featurette: anything that holds nothing.
    case leaf(Leaf)
    /// A child container, named by its id.
    case child(Child)
    /// An item declared elsewhere, in this container or another.
    case ref(EntryRef)

    /// The id, unique within the container. A ref has none.
    public var id: ItemID? {
        switch self {
        case .leaf(let leaf): leaf.id
        case .child(let child): child.id
        case .ref: nil
        }
    }

    public struct Leaf: Hashable, Sendable {
        public var id: ItemID
        public var type: EntryType
        public var optional: Bool
        /// A title and outline only when no provider has one for it.
        public var title: String?
        public var outline: String?
        public var externalRefs: [ExternalRef]

        public init(
            id: ItemID,
            type: EntryType,
            optional: Bool = false,
            title: String? = nil,
            outline: String? = nil,
            externalRefs: [ExternalRef] = []
        ) {
            self.id = id
            self.type = type
            self.optional = optional
            self.title = title
            self.outline = outline
            self.externalRefs = externalRefs
        }
    }

    public struct Child: Hashable, Sendable {
        public var id: ItemID
        public var container: ContainerID
        public var optional: Bool
        /// A title and outline only when no provider has one for it.
        public var title: String?
        public var outline: String?
        public var externalRefs: [ExternalRef]

        public init(
            id: ItemID,
            container: ContainerID,
            optional: Bool = false,
            title: String? = nil,
            outline: String? = nil,
            externalRefs: [ExternalRef] = []
        ) {
            self.id = id
            self.container = container
            self.optional = optional
            self.title = title
            self.outline = outline
            self.externalRefs = externalRefs
        }
    }
}

/// What a leaf is. Open, like a provider, except that it is never `container`: a child container
/// is an entry of its own kind, `Entry.child`, and not a leaf with that type.
public struct EntryType: Hashable, Sendable, Codable, RawRepresentable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard rawValue != "container" else { return nil }
        self.rawValue = rawValue
    }

    private init(named: String) {
        rawValue = named
    }

    public static let episode = EntryType(named: "episode")
    public static let movie = EntryType(named: "movie")
    public static let featurette = EntryType(named: "featurette")

    public var description: String { rawValue }
}

/// An item in another sequence of the same container, or, with a container id, in any container.
public struct EntryRef: Hashable, Sendable {
    public var container: ContainerID?
    public var item: ItemID

    public init(container: ContainerID? = nil, item: ItemID) {
        self.container = container
        self.item = item
    }
}
