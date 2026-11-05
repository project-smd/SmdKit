<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: The container's fields are written in a fixed order, and empty ones are omitted
Under the root the writer SHALL emit, in this order: `<title>`; `<year>` when the year is set,
with `inTitle="true"` when `yearInTitle` is true; `<premiered>` when the container has a first date,
as `yyyy-mm-dd`; `<typeLabel>`; `<outline>`; one `<externalRef provider="…" value="…"/>` per external
reference; `<cast>` and then `<crew>`, each holding one `<participant name role>` per participant in
the order credited; `<alternatives>` with a `default`
attribute when one is set, holding one `<alternative id sequence>` per alternative with its
`<title>` and `<outline>`; `<features>` holding one `<feature id type>` per feature with its
`<title>` and one `<participant name role>` per participant; one `<sequence>` per sequence, with
`id` when set and `exploded` only when it is not `never`; and `<extras>`, with `anchor` when set,
when there are extras or an anchor. Every `<participant>`, in the cast, the crew or a feature, SHALL
hold one `<externalRef provider="…" value="…"/>` per external reference of the participant's. A text
element whose value is nil or empty, an attribute whose value is nil, and an `<alternatives>`,
`<features>`, `<cast>` or `<crew>` with nothing in it SHALL be omitted.

#### Scenario: a year that is part of the name
- **WHEN** a series with `year` 1963 and `yearInTitle` true is written
- **THEN** the document has `<year inTitle="true">1963</year>`

#### Scenario: a year kept apart
- **WHEN** a season with `year` 1976 and `yearInTitle` false is written
- **THEN** the document has `<year>1976</year>` with no `inTitle` attribute

#### Scenario: an exploded sequence
- **WHEN** a sequence with id `dvd-order` and `exploded` `allowed` is written
- **THEN** its element is `<sequence id="dvd-order" exploded="allowed">`

#### Scenario: an episode with its credits
- **WHEN** an episode container that premiered on 2022-09-21, with two of its cast, one with a character
  and a provider's reference and one with neither, and a director, is written and read
- **THEN** the document has `<premiered>2022-09-21</premiered>` after its title, a `<cast>` holding the
  two participants in order and then a `<crew>` holding the director, the first participant holds an
  `<externalRef>`, and the container reads back equal

#### Scenario: a participant on a feature known to a provider
- **WHEN** a commentary feature whose participant carries a `tmdb` reference is written and read
- **THEN** the `<participant>` holds an `<externalRef>` with that provider and value, and the
  participant reads back with it

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`theFieldsAreWrittenInTheirOrder`, `aContainersCreditsAreWrittenInTheirOrder`,
`aParticipantCarriesItsReferences`, `containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

### Requirement: The reader refuses values outside each closed vocabulary
The reader SHALL throw `invalidValue` for a root `type` that is not a `ContainerType`, a sequence
`exploded` that is not an `Exploded`, and a boolean attribute (`listed`, `inTitle`, `optional`)
that is neither `true` nor `false`; `invalidText` for a `<year>` whose text is not an integer, for a
`<premiered>` whose text is not a calendar date written `yyyy-mm-dd`, and for a `<title>` that `Title.init?(_:)` refuses; and `missingElement` for a container with no
`<title>`. `missingAttribute` for a `<participant>` with no `name`. Provider, entry type and feature type SHALL be read as given, since they are open.

#### Scenario: an unknown container type
- **WHEN** an otherwise valid container document with `type="box"` is read
- **THEN** the read throws `invalidValue(element: "container", attribute: "type", value: "box")`

#### Scenario: no title
- **WHEN** an otherwise valid container document with no `<title>` is read
- **THEN** the read throws `missingElement(element: "container", child: "title")`

#### Scenario: a blank title
- **WHEN** an otherwise valid container document whose `<title>` holds only spaces is read
- **THEN** the read throws `invalidText` for the `title` element

#### Scenario: a first date that is not a date
- **WHEN** an otherwise valid container document whose `<premiered>` is `2022-13-01` is read
- **THEN** the read throws `invalidText` for the `premiered` element

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).
