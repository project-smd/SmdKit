<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Slugs

## Purpose

The ids inside a container — of items, sequences, alternatives and features — are slugs: lowercase
ASCII letters, digits and hyphens, local to the container and chosen by whoever authors it. `Slug`
makes a first one from a title, makes one that avoids the ids already taken, and says whether a
string is one. It is not used by the container file's reader, which does not check local ids.

Documentation: [README](../../../README.md).

## Requirements

### Requirement: A slug is made by folding the title and joining its runs of letters and digits
`Slug.make(from:)` SHALL fold the title diacritic- and case-insensitively and lowercase it, keep
each ASCII letter `a`–`z` and digit `0`–`9`, and replace every run of other characters between two
kept characters with a single hyphen, so the result has no leading, trailing or doubled hyphen.
When nothing is kept the result SHALL be `item`.

#### Scenario: punctuation and spacing collapse
- **WHEN** `Slug.make(from: "The Talons of Weng-Chiang")` is called
- **THEN** it returns `the-talons-of-weng-chiang`

#### Scenario: leading and trailing separators are dropped
- **WHEN** `Slug.make(from: "  Pyramids of Mars: Part 1 (1975) ")` is called
- **THEN** it returns `pyramids-of-mars-part-1-1975`

#### Scenario: accents are stripped
- **WHEN** `Slug.make(from: "Café Ünïcode")` is called
- **THEN** it returns `cafe-unicode`

#### Scenario: nothing usable
- **WHEN** `Slug.make(from: "???")` is called
- **THEN** it returns `item`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`slugsAreMadeFromTitles`).

### Requirement: A unique slug takes the first free numeric suffix
`Slug.unique(from:avoiding:)` SHALL return the slug of the title when it is not in the taken set,
and otherwise the first of `<slug>-2`, `<slug>-3`, … that is not in the set.

#### Scenario: the base and the first suffix are taken
- **WHEN** `Slug.unique(from: "Part 1", avoiding: ["part-1", "part-1-2"])` is called
- **THEN** it returns `part-1-3`

#### Scenario: nothing is taken
- **WHEN** `Slug.unique(from: "Part 1", avoiding: [])` is called
- **THEN** it returns `part-1`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`slugsAreMadeFromTitles`).

### Requirement: A valid slug is non-empty lowercase ASCII with inner hyphens only
`Slug.isValid(_:)` SHALL return true exactly when the string is non-empty, neither starts nor ends
with a hyphen, and consists only of `a`–`z`, `0`–`9` and `-`. It SHALL NOT reject doubled hyphens.

#### Scenario: a slug
- **WHEN** `Slug.isValid("season-14")` is called
- **THEN** it returns true

#### Scenario: a leading hyphen
- **WHEN** `Slug.isValid("-season")` is called
- **THEN** it returns false

#### Scenario: uppercase and a space
- **WHEN** `Slug.isValid("Season 14")` is called
- **THEN** it returns false

#### Scenario: a doubled hyphen
- **WHEN** `Slug.isValid("part--1")` is called
- **THEN** it returns true, although `Slug.make` never produces one

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`slugsAreMadeFromTitles`).
