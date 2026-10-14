<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: Providers, entry types and feature types are open vocabularies
`Provider`, `EntryType` and `FeatureType` SHALL each be a string wrapper, so a new provider or kind
is a string rather than a code change. `Provider` and `FeatureType` SHALL accept any raw value.
`EntryType.init?(rawValue:)` SHALL accept any raw value except `container` and SHALL return `nil`
for that one, because a child container is a case of `Entry` of its own rather than an entry type.
The package SHALL name the common ones as constants: providers `tvdb`, `tmdb`, `imdb`,
`wikidata`, `thediscdb`, `upc` and `asin`; entry types `episode`, `movie`, `featurette`,
`behindTheScenes`, `deletedScene`, `interview`, `trailer`, `scene`, `short`, `clip`, `themeSong` and
`themeVideo`; feature types `commentary` and `isolatedMusic`. `Provider.known` SHALL list `tvdb`, `tmdb`,
`imdb`, `wikidata` in that order. `Provider.title` SHALL give each named provider's display name
and SHALL be the raw value for any other provider. `EntryType.extraTypes` SHALL list the types an
extra is classified by, which are Emby's `ExtraType`: `featurette`, `behindTheScenes`,
`deletedScene`, `interview`, `trailer`, `scene`, `short`, `clip`, `themeSong` and `themeVideo`, in
that order. The list names the types offered for an extra, not the ones it may have: an extra MAY
have any entry type, and an entry of a listed type MAY be held in a sequence.

#### Scenario: an unnamed provider
- **WHEN** `Provider(rawValue: "anidb").title` is read
- **THEN** it is `anidb`

#### Scenario: a named provider
- **WHEN** `Provider.tmdb.title` is read
- **THEN** it is `TMDb`

#### Scenario: an unnamed entry type
- **WHEN** `EntryType(rawValue: "special")` is evaluated
- **THEN** it returns an entry type whose `rawValue` is `special`

#### Scenario: the types an extra is classified by
- **WHEN** `EntryType.extraTypes` is read
- **THEN** it is the ten named extra types with `featurette` first and `themeVideo` last, and it does not contain `movie`

#### Scenario: the container entry type
- **WHEN** `EntryType(rawValue: "container")` is evaluated
- **THEN** it returns `nil`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`entryTypesAreOpenExceptForContainer`, `extrasAreClassifiedByEmbysExtraTypes`).
