<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: An entry's kind determines its fields
`Entry` SHALL be an enum of three cases. `leaf(Entry.Leaf)` is an episode, a film, a featurette or
any other entry that holds nothing, and carries an `ItemID`, an `EntryType`, `optional`, an
optional title and outline, and external references. `child(Entry.Child)` is a child container,
and carries an `ItemID`, the child's `ContainerID`, `optional`, an optional title and outline, and
external references. `ref(EntryRef)` names an item declared elsewhere, and carries an optional
`ContainerID` and an `ItemID`. `Entry.id` SHALL be the leaf's or the child's id, and `nil` for a
ref. So a child always names a container, a leaf never does, and a ref has no id, no type, no
title and no external references.

#### Scenario: a ref entry
- **WHEN** an entry is built as a ref to the item id `part2` with no container id
- **THEN** its `id` is `nil` and it names `part2` in the same container

#### Scenario: a child entry
- **WHEN** an entry is built as a child with item id `s1` naming the container with id `0123456789abcdef`
- **THEN** its `id` is `s1`, and it names that container as its child

Pinned by: nothing yet.

### Requirement: An item id is non-empty and names one item
`ItemID.init?(rawValue:)` SHALL accept a string exactly when it is non-empty and contains no `#`,
no tab, line feed or carriage return, and no character outside XML 1.0's `Char` production, and
SHALL return `nil` otherwise. `ItemID` SHALL be `Hashable`, `Sendable` and `Codable`, encoding as
its raw value, and decoding a string it would refuse SHALL throw. The `#` is refused because it
separates the container from the item in a ref into another container. Tab and the line breaks are
refused because an attribute holding one reads back with a space in its place.

#### Scenario: a slug
- **WHEN** `ItemID(rawValue: "part1")` is evaluated
- **THEN** it returns an id whose `rawValue` is `part1`

#### Scenario: an empty id
- **WHEN** `ItemID(rawValue: "")` is evaluated
- **THEN** it returns `nil`

#### Scenario: an id holding the ref separator
- **WHEN** `ItemID(rawValue: "a#b")` is evaluated
- **THEN** it returns `nil`

#### Scenario: an id holding a line feed
- **WHEN** `ItemID(rawValue:)` is given `a`, a line feed and `b`
- **THEN** it returns `nil`

Pinned by: nothing yet.

### Requirement: A container title is non-empty trimmed text
`Title.init?(_:)` SHALL trim whitespace and newlines from both ends of the string it is given, and
SHALL return `nil` when nothing is left or when the string contains a character outside XML 1.0's
`Char` production. `Title.rawValue` SHALL be the trimmed string. `Container.title` SHALL be a
`Title`, so a container cannot be built with an empty or blank title. `Title` SHALL be `Codable`,
encoding as its raw value, and decoding a string it would refuse SHALL throw.

#### Scenario: surrounding spaces
- **WHEN** `Title(" Doctor Who ")` is evaluated
- **THEN** it returns a title whose `rawValue` is `Doctor Who`

#### Scenario: a blank title
- **WHEN** `Title("   ")` is evaluated
- **THEN** it returns `nil`

#### Scenario: a control character
- **WHEN** `Title` is given a string holding U+0001
- **THEN** it returns `nil`

Pinned by: nothing yet.

## MODIFIED Requirements

### Requirement: A container id is sixteen lowercase hex characters
`ContainerID.init?(rawValue:)` SHALL accept a string exactly when it is sixteen characters long and
every character is a digit `0`–`9` or a lowercase letter `a`–`f`, and SHALL return `nil` otherwise.
It SHALL check only the shape, so an id drawn by any tool is accepted. `ContainerID.init?(_:)`
SHALL behave the same. No public initialiser SHALL build an id without the check, and decoding a
string that is not an id SHALL throw `DecodingError.dataCorrupted`.

#### Scenario: a well-formed id
- **WHEN** `ContainerID("0123456789abcdef")` is evaluated
- **THEN** it returns an id whose `rawValue` and `description` are that string

#### Scenario: uppercase hex
- **WHEN** `ContainerID("0123456789ABCDEF")` is evaluated
- **THEN** it returns `nil`

#### Scenario: a UUID
- **WHEN** a hyphenated UUID string is passed to `ContainerID(_:)`
- **THEN** it returns `nil`, because it is neither sixteen characters nor hex throughout

#### Scenario: the raw-value initialiser
- **WHEN** `ContainerID(rawValue: "not-an-id")` is evaluated
- **THEN** it returns `nil`

#### Scenario: a malformed id in JSON
- **WHEN** the JSON string `"not-an-id"` is decoded as a `ContainerID`
- **THEN** decoding throws `DecodingError.dataCorrupted`

Pinned by: nothing yet.

### Requirement: Providers, entry types and feature types are open vocabularies
`Provider`, `EntryType` and `FeatureType` SHALL each be a string wrapper, so a new provider or kind
is a string rather than a code change. `Provider` and `FeatureType` SHALL accept any raw value.
`EntryType.init?(rawValue:)` SHALL accept any raw value except `container` and SHALL return `nil`
for that one, because a child container is a case of `Entry` of its own rather than an entry type.
The package SHALL name the common ones as constants: providers `tvdb`, `tmdb`, `imdb`,
`wikidata`, `thediscdb`, `upc` and `asin`; entry types `episode`, `movie` and `featurette`;
feature types `commentary` and `isolatedMusic`. `Provider.known` SHALL list `tvdb`, `tmdb`,
`imdb`, `wikidata` in that order. `Provider.title` SHALL give each named provider's display name
and SHALL be the raw value for any other provider.

#### Scenario: an unnamed provider
- **WHEN** `Provider(rawValue: "anidb").title` is read
- **THEN** it is `anidb`

#### Scenario: a named provider
- **WHEN** `Provider.tmdb.title` is read
- **THEN** it is `TMDb`

#### Scenario: an unnamed entry type
- **WHEN** `EntryType(rawValue: "special")` is evaluated
- **THEN** it returns an entry type whose `rawValue` is `special`

#### Scenario: the container entry type
- **WHEN** `EntryType(rawValue: "container")` is evaluated
- **THEN** it returns `nil`

Pinned by: nothing yet.

### Requirement: Children are the container items of the sequences and extras
`Container.childContainerIDs` SHALL be the `container` id of every `Entry.child`, across all
sequences in order and then the extras in order. A ref SHALL NOT count as a child, even when it
names an item in another container. `Container.itemIDs` SHALL be the set of the ids of every leaf
and every child in the sequences and extras; refs declare none.

#### Scenario: a series holding a season
- **WHEN** a series's only sequence holds a child entry with item id `season-14` naming a season
- **THEN** its `childContainerIDs` is the season's id alone, and its `itemIDs` is `season-14` alone

#### Scenario: a ref into another container
- **WHEN** a container has no sequences and its extras hold only a ref to an item of another container
- **THEN** its `childContainerIDs` is empty and its `itemIDs` is empty

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`childrenAreNamedByIdentity`). `itemIDs`, and that a ref is not a child, are not yet measured.

## REMOVED Requirements

### Requirement: An entry's fields are not checked against its kind
**Reason**: `Entry` becomes an enum with one case per kind, so a child always names a container, a leaf never does, and the combinations the reader refused can no longer be built.
**Migration**: See "An entry's kind determines its fields". Build `Entry.leaf`, `Entry.child` or `Entry.ref` in place of `Entry(id:type:container:)`, and `Entry.Child(id:container:)` in place of `Entry.child(_:id:)`.
