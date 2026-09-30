<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Container model

## Purpose

`Container` and the types under it are the sidecar proposal's elements as values: a container of
a given type, its alternatives, features, sequences of items, and extras, named as the proposal
names them, with external references where a library would keep an NFO and children named by
identity rather than by path. This spec covers container identity, the closed and open
vocabularies, and the facts derived from a container's value. How a container is written to and
read from a file is the `container-file` spec's.

Documentation: [README](../../../README.md), and the proposals in
[smddb](https://github.com/project-smd/smddb) (`StructuredContainers.md`, `ContainerDatabase.md`).

## Requirements

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerIDsAreCheckedEverywhere`).

### Requirement: Minting draws 64 random bits
`ContainerID.mint()` SHALL return an id formed from a uniformly random 64-bit value written as
sixteen zero-padded lowercase hex digits, which `ContainerID.init?(_:)` accepts. A `Container`
created without an explicit id SHALL be given a freshly minted one.

#### Scenario: a minted id is valid
- **WHEN** `ContainerID.mint()` is called
- **THEN** `ContainerID(minted.rawValue)` returns the same id

#### Scenario: two containers created without ids
- **WHEN** two containers are created with `Container(type:title:)` and no `id:`
- **THEN** each has a minted id, and the two differ

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerIDsAreCheckedEverywhere`, `childrenAreNamedByIdentity`, `repositoryKeepsOneFilePerContainer`).

### Requirement: A container type is one of eight
`ContainerType` SHALL be exactly `series`, `season`, `serial`, `arc`, `volume`, `collection`,
`episode` and `movie`, each with a raw value equal to its name and a `title` that is its name
capitalised. `hasYear` SHALL be true for `series`, `season` and `movie` and false for the others.

#### Scenario: a type with a year of its own
- **WHEN** `ContainerType.season.hasYear` is read
- **THEN** it is `true`

#### Scenario: a type that takes its year from elsewhere
- **WHEN** `ContainerType.serial.hasYear` is read
- **THEN** it is `false`

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`entryTypesAreOpenExceptForContainer`).

### Requirement: Open vocabularies encode as their bare string
`ContainerID`, `Provider`, `EntryType`, `FeatureType`, `ContainerType`, `Exploded` and
`ExternalRef` SHALL be `Codable`, and each string-wrapping type SHALL encode as a single string
value equal to its raw value, so a kind reads the same in JSON as in the container file.

#### Scenario: an entry type in JSON
- **WHEN** `EntryType.featurette` is encoded with `JSONEncoder`
- **THEN** the output is the JSON string `"featurette"`, and decoding it yields `EntryType.featurette`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`entryTypesAreOpenExceptForContainer`). Only the entry type's encoding is measured.

### Requirement: The display title carries the year only when the year is part of the name
`Container.displayTitle` SHALL be the title followed by a space and the year in parentheses when
`yearInTitle` is true and `year` is set, and SHALL be the title alone otherwise.

#### Scenario: year in the title
- **WHEN** a series titled `Doctor Who` has `year` 1963 and `yearInTitle` true
- **THEN** its `displayTitle` is `Doctor Who (1963)`

#### Scenario: year kept apart from the title
- **WHEN** a season titled `Season 14` has `year` 1976 and `yearInTitle` false
- **THEN** its `displayTitle` is `Season 14`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`childrenAreNamedByIdentity`).

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`childrenAreNamedByIdentity`, `anEntrysKindDeterminesItsFields`).

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`anEntrysKindDeterminesItsFields`).

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`itemIDsNameOneItem`).

### Requirement: A container title is non-empty trimmed text
`Title.init?(_:)` SHALL trim whitespace and newlines from both ends of the string it is given, and
SHALL return `nil` when nothing is left or when the string contains a character outside XML 1.0's
`Char` production. `Title.rawValue` SHALL be the trimmed string. `Title.init?(rawValue:)` SHALL
accept exactly the strings `Title.init?(_:)` returns unchanged, so it refuses untrimmed text rather
than altering it. `Container.title` SHALL be a `Title`, so a container cannot be built with an
empty or blank title. `Title` SHALL be `Codable`, encoding as its raw value, and decoding a string
that `Title.init?(rawValue:)` refuses SHALL throw.

#### Scenario: surrounding spaces
- **WHEN** `Title(" Doctor Who ")` is evaluated
- **THEN** it returns a title whose `rawValue` is `Doctor Who`

#### Scenario: a blank title
- **WHEN** `Title("   ")` is evaluated
- **THEN** it returns `nil`

#### Scenario: a control character
- **WHEN** `Title` is given a string holding U+0001
- **THEN** it returns `nil`

#### Scenario: an untrimmed raw value
- **WHEN** `Title(rawValue: " Doctor Who")` is evaluated
- **THEN** it returns `nil`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`titlesAreTrimmedAndNonEmpty`).
