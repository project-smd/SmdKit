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
`ContainerID.init?(_:)` SHALL accept a string exactly when it is sixteen characters long and every
character is a digit `0`–`9` or a lowercase letter `a`–`f`, and SHALL return `nil` otherwise. It
SHALL check only the shape, so an id drawn by any tool is accepted. `ContainerID(rawValue:)` SHALL
NOT check the shape.

#### Scenario: a well-formed id
- **WHEN** `ContainerID("0123456789abcdef")` is evaluated
- **THEN** it returns an id whose `rawValue` and `description` are that string

#### Scenario: uppercase hex
- **WHEN** `ContainerID("0123456789ABCDEF")` is evaluated
- **THEN** it returns `nil`

#### Scenario: a UUID
- **WHEN** a hyphenated UUID string is passed to `ContainerID(_:)`
- **THEN** it returns `nil`, because it is neither sixteen characters nor hex throughout

Pinned by: nothing yet.

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`childrenAreNamedByIdentity`, `repositoryKeepsOneFilePerContainer`).

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
`Provider`, `EntryType` and `FeatureType` SHALL each be a string wrapper that accepts any raw
value, so a new provider or kind is a string rather than a code change. The package SHALL name the
common ones as constants: providers `tvdb`, `tmdb`, `imdb`, `wikidata`, `thediscdb`, `upc` and
`asin`; entry types `episode`, `movie`, `container` and `featurette`; feature types `commentary`
and `isolatedMusic`. `Provider.known` SHALL list `tvdb`, `tmdb`, `imdb`, `wikidata` in that order.
`Provider.title` SHALL give each named provider's display name and SHALL be the raw value for any
other provider.

#### Scenario: an unnamed provider
- **WHEN** `Provider(rawValue: "anidb").title` is read
- **THEN** it is `anidb`

#### Scenario: a named provider
- **WHEN** `Provider.tmdb.title` is read
- **THEN** it is `TMDb`

Pinned by: nothing yet.

### Requirement: Open vocabularies encode as their bare string
`ContainerID`, `Provider`, `EntryType`, `FeatureType`, `ContainerType`, `Exploded` and
`ExternalRef` SHALL be `Codable`, and each string-wrapping type SHALL encode as a single string
value equal to its raw value, so a kind reads the same in JSON as in the container file.

#### Scenario: an entry type in JSON
- **WHEN** `EntryType.featurette` is encoded with `JSONEncoder`
- **THEN** the output is the JSON string `"featurette"`, and decoding it yields `EntryType.featurette`

Pinned by: nothing yet.

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
`Container.childContainerIDs` SHALL be the `container` id of every entry that has one, across all
sequences in order and then the extras in order. A ref SHALL NOT count as a child, even when it
names an item in another container. `Container.itemIDs` SHALL be the set of every entry id declared
in the sequences and extras; refs declare none. `Entry.child(_:id:)` SHALL make an entry of type
`container` naming the given container's id.

#### Scenario: a series holding a season
- **WHEN** a series's only sequence holds `Entry.child(season, id: "season-14")`
- **THEN** its `childContainerIDs` is the season's id alone

#### Scenario: a ref into another container
- **WHEN** a container has no sequences and its extras hold only a ref to an item of another container
- **THEN** its `childContainerIDs` is empty and its `itemIDs` is empty

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`childrenAreNamedByIdentity`). `itemIDs`, and that a ref is not a child, are not yet measured.

### Requirement: An entry's fields are not checked against its kind
`Entry` SHALL NOT enforce which fields go with which kind: an entry of type `container` may be
built without a `container` id, and an entry of any other type may be built with one. A ref,
built with `Entry(ref:)`, SHALL have no id, no type, `optional` false and no external references.
The value types accept combinations that the container file's reader refuses, which is tracked as
a defect in https://github.com/project-smd/SmdKit/issues/7.

#### Scenario: a ref entry
- **WHEN** an entry is built with `Entry(ref: EntryRef(item: "part2"))`
- **THEN** its `id` and `type` are `nil` and its `ref` names `part2` in the same container

#### Scenario: a container entry with no child
- **WHEN** an entry is built with `Entry(id: "s1", type: .container)` and no `container:`
- **THEN** the entry is created, with `container` nil

Pinned by: nothing yet.
