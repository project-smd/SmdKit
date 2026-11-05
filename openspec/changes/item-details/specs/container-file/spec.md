<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: The container's fields are written in a fixed order, and empty ones are omitted
Under the root the writer SHALL emit, in this order: `<title>`; `<year>` when the year is set,
with `inTitle="true"` when `yearInTitle` is true; `<typeLabel>`; `<outline>`; one
`<externalRef provider="…" value="…"/>` per external reference; `<alternatives>` with a `default`
attribute when one is set, holding one `<alternative id sequence>` per alternative with its
`<title>` and `<outline>`; `<features>` holding one `<feature id type>` per feature with its
`<title>` and one `<participant name role>` per participant, holding one
`<externalRef provider="…" value="…"/>` per external reference of the participant's; one `<sequence>` per sequence, with
`id` when set and `exploded` only when it is not `never`; and `<extras>`, with `anchor` when set,
when there are extras or an anchor. A text element whose value is nil or empty, an attribute whose
value is nil, and an `<alternatives>` or `<features>` with nothing in it SHALL be omitted.

#### Scenario: a year that is part of the name
- **WHEN** a series with `year` 1963 and `yearInTitle` true is written
- **THEN** the document has `<year inTitle="true">1963</year>`

#### Scenario: a year kept apart
- **WHEN** a season with `year` 1976 and `yearInTitle` false is written
- **THEN** the document has `<year>1976</year>` with no `inTitle` attribute

#### Scenario: an exploded sequence
- **WHEN** a sequence with id `dvd-order` and `exploded` `allowed` is written
- **THEN** its element is `<sequence id="dvd-order" exploded="allowed">`

#### Scenario: a participant known to a provider
- **WHEN** a commentary feature whose participant carries a `tmdb` reference is written and read
- **THEN** the `<participant>` holds an `<externalRef>` with that provider and value, and the
  participant reads back with it

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`theFieldsAreWrittenInTheirOrder`, `aParticipantCarriesItsReferences`, `containerSurvivesTheFile`, `childrenAreNamedByIdentity`).
