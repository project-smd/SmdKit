<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Container file

## Purpose

`ContainerFile` writes one container as the XML document the data repository keeps and reads such
a document back. The document is the sidecar's `<container>` element with a library's facts taken
out and the database's put in: a global id, children named by `container="<id>"`, and
`<externalRef>` elements, with no `<presentation>` and no `smd` paths. This spec covers the
document's shape, the round trip, and everything the reader refuses.

Documentation: [README](../../../README.md) ("The repository layout").

## Requirements

### Requirement: The document is rooted at a versioned container element
`ContainerFile.data(for:)` SHALL produce a UTF-8 XML 1.0 document whose root is
`<container format="1" id="<id>" type="<type>">`, with `listed="false"` added only when the
container is not listed. `ContainerFile.format` SHALL be 1 and `ContainerFile.fileName(for:)` SHALL
be the id followed by `.xml`. The document SHALL be the same bytes on every platform: the first
line is exactly `<?xml version="1.0" encoding="UTF-8"?>`, with no `standalone` declaration; each
element starts on its own line, indented by four spaces for each element that encloses it; an
element holding only text is written on one line with its text; an element with no content is
written in its compact form; and the document ends in a line feed. Text escapes `&`, `<` and `>`;
an attribute value escapes those and `"`.

#### Scenario: a listed container
- **WHEN** a listed serial is written
- **THEN** the root element carries `format`, `id` and `type` and no `listed` attribute

#### Scenario: an unlisted container
- **WHEN** a series with `listed` false is written
- **THEN** the root element carries `listed="false"`

#### Scenario: the byte form
- **WHEN** a serial with a title holding an ampersand and angle brackets, an external ref, and one sequence of two episodes, one with a title and one without, is written
- **THEN** the declaration is the first line, the sequence is indented by four spaces and its items by eight, the titled episode's title is on its own line inside it, the untitled episode is one compact element, the title's special characters are escaped, and the same bytes are written on macOS and Linux

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`, `theFileIsTheSameBytesOnEveryPlatform`).

### Requirement: The container's fields are written in a fixed order, and empty ones are omitted
Under the root the writer SHALL emit, in this order: `<title>`; `<year>` when the year is set,
with `inTitle="true"` when `yearInTitle` is true; `<typeLabel>`; `<outline>`; one
`<externalRef provider="…" value="…"/>` per external reference; `<alternatives>` with a `default`
attribute when one is set, holding one `<alternative id sequence>` per alternative with its
`<title>` and `<outline>`; `<features>` holding one `<feature id type>` per feature with its
`<title>` and one `<participant name role>` per participant; one `<sequence>` per sequence, with
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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`theFieldsAreWrittenInTheirOrder`, `containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

### Requirement: Items are written as the sidecar spells them, with children and refs by id
Each entry SHALL be written as `<item>`. A ref SHALL be written with only a `ref` attribute, whose
value is the item id for a ref within the container and `<container id>#<item id>` for a ref into
another container. A leaf SHALL carry its `type`, then `id`, and `optional="true"` only when
optional. A child SHALL carry `type="container"`, then `id`, `optional="true"` only when optional,
and `container="<id>"`. A leaf or a child SHALL then carry its `<title>`, `<outline>` and external
references. The document SHALL NOT contain `<presentation>` elements or `smd` attributes.

#### Scenario: a child container item
- **WHEN** a series whose sequence holds a child season with item id `season-14` is written
- **THEN** the item is written with `type="container"`, `id="season-14"` and `container` set to the season's id

#### Scenario: a ref into another container
- **WHEN** an extra is a ref to item `s14-talons` of the container with id `0b9e8d7c6f5a4b3c`
- **THEN** the item is written as `<item ref="0b9e8d7c6f5a4b3c#s14-talons"/>`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`, `itemsAreSpelledAsTheSidecarSpellsThem`).

### Requirement: A written container reads back equal
`ContainerFile.container(from: ContainerFile.data(for: c))` SHALL equal `c` when every string in
`c` other than a `ContainerID` or an `ItemID` holds only characters XML 1.0 can carry and no
carriage return; when every such string written as an attribute holds no tab or line feed either;
when every optional text field is either nil or non-empty with no leading or trailing whitespace;
when `yearInTitle` is true only with a year; and when a default alternative is set only with
alternatives. Outside those conditions the value SHALL still be read back, per "Every written
container can be read back", but it comes back different: an empty optional text as nil, text with
surrounding whitespace trimmed, a carriage return (alone or before a line feed) as a line feed, a
tab or line break in an attribute as a space, with a carriage return and line feed as one space, a
character XML 1.0 cannot carry removed, `yearInTitle` without a year as false, and a default without
alternatives as nil. The writer SHALL fold the carriage returns, and the tabs and line breaks in
attributes, before it writes, so the file holds each value as it reads back and a value reads back
the same whichever platform wrote it.

#### Scenario: the worked example
- **WHEN** a serial with three alternatives, two features, three sequences including one of refs, an extras anchor and a cross-container ref is written and read back with its own id expected
- **THEN** the value read equals the value written

#### Scenario: line ends in text
- **WHEN** a container whose outline is `one`, a carriage return and line feed, `two`, a carriage return and `three` is written and read back
- **THEN** the outline read is `one`, a line feed, `two`, a line feed and `three`

#### Scenario: whitespace in an attribute
- **WHEN** a sequence whose id is `a`, a tab, `b`, a carriage return and line feed, and `c` is written and read back
- **THEN** the sequence id read is `a b c`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`, `everyWrittenContainerReadsBack`, `aRoundTripDriftsOnlyAsStated`).

### Requirement: Text is trimmed on read
The reader SHALL trim leading and trailing whitespace and newlines from the text of every element
it reads as text — titles, type labels and outlines — so a document may indent that text freely,
and whitespace at either end of such a value does not survive a round trip. The text of `<year>`
SHALL NOT be trimmed, so a year written with surrounding whitespace throws `invalidText`.

#### Scenario: surrounding whitespace
- **WHEN** a container whose outline has a leading and a trailing space is written and read back
- **THEN** the outline read has neither space

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`textIsTrimmedOnRead`, `fileRefusesWhatItCannotRead`).

### Requirement: The reader refuses a document that is not a well-formed container
`ContainerFile.container(from:expecting:)` SHALL first check well-formedness with the event parser
and throw `malformed` when it reports an error or fails, on Linux as on Darwin, so a truncated
document is never read as the tree a recovering parser would close for it. It SHALL throw
`notAContainer` when the root element is not `<container>`.

#### Scenario: a truncated document
- **WHEN** a document whose `<container>` is never closed is read
- **THEN** the read throws a `ContainerFileError`

#### Scenario: a different root
- **WHEN** a document rooted at `<sequence>` is read
- **THEN** the read throws `notAContainer`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader refuses a newer format and an id it cannot trust
The root SHALL carry an integer `format`, else `missingAttribute` or `invalidValue`; a format
greater than `ContainerFile.format` SHALL throw `unsupportedFormat` with that number rather than be
half-read. The root `id` SHALL be required and SHALL pass `ContainerID.init?(_:)`, else
`invalidValue`. When `expecting` is given and differs from the document's id, the reader SHALL
throw `idMismatch(file:document:)`.

#### Scenario: a newer format
- **WHEN** a container document with `format="2"` is read
- **THEN** the read throws `unsupportedFormat(2)`

#### Scenario: a file named for another container
- **WHEN** a document with id A is read expecting id B
- **THEN** the read throws `idMismatch(file: B, document: A)`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader refuses values outside each closed vocabulary
The reader SHALL throw `invalidValue` for a root `type` that is not a `ContainerType`, a sequence
`exploded` that is not an `Exploded`, and a boolean attribute (`listed`, `inTitle`, `optional`)
that is neither `true` nor `false`; `invalidText` for a `<year>` whose text is not an integer and
for a `<title>` that `Title.init?(_:)` refuses; and `missingElement` for a container with no
`<title>`. Provider, entry type and feature type SHALL be read as given, since they are open.

#### Scenario: an unknown container type
- **WHEN** an otherwise valid container document with `type="box"` is read
- **THEN** the read throws `invalidValue(element: "container", attribute: "type", value: "box")`

#### Scenario: no title
- **WHEN** an otherwise valid container document with no `<title>` is read
- **THEN** the read throws `missingElement(element: "container", child: "title")`

#### Scenario: a blank title
- **WHEN** an otherwise valid container document whose `<title>` holds only spaces is read
- **THEN** the read throws `invalidText` for the `title` element

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader enforces the item forms
An `<item>` with a `ref` attribute SHALL carry neither `id` nor `type`, else the reader throws
`refWithIdentity`. A ref of the form `<a>#<b>` SHALL have a valid container id before the `#` and
an item id that `ItemID` accepts after it, and a ref without a `#` SHALL be an item id that
`ItemID` accepts, else `invalidValue`. Any other item SHALL carry `type` and `id`, and its `id`
SHALL be accepted by `ItemID`, else `invalidValue`. An item of type `container` is read as a child
and SHALL carry a valid `container` id, else `missingAttribute` when it has none and
`invalidValue` when it is not an id. An item of any other type is read as a leaf and SHALL NOT
carry a `container` attribute, else `invalidValue`.

#### Scenario: a ref with an id
- **WHEN** an item with both `ref="part1"` and an `id` is read
- **THEN** the read throws `refWithIdentity("part1")`

#### Scenario: a container item with no child
- **WHEN** an item with `type="container"` and no `container` attribute is read
- **THEN** the read throws `missingAttribute(element: "item", attribute: "container")`

#### Scenario: an episode naming a child
- **WHEN** an item with `type="episode"` and a `container` attribute is read
- **THEN** the read throws `invalidValue` for the `container` attribute

#### Scenario: an empty item id
- **WHEN** an item with `type="episode"` and `id=""` is read
- **THEN** the read throws `invalidValue(element: "item", attribute: "id", value: "")`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader ignores what it does not know
The reader SHALL ignore elements and attributes it does not read, including `<presentation>`
elements, `smd` attributes and a `<rules>` element, so a sidecar read with `ContainerFile` yields
its container unchanged. A document `ContainerFile.data(for:)` writes SHALL hold no `<rules>`
element, since a container has no rules: they are a library's fact, kept only in its sidecar. The
reader SHALL NOT check that local ids are unique or slugs, that an alternative's sequence exists,
that the default names an alternative, or that the extras anchor names an item.

#### Scenario: a sidecar read as a container
- **WHEN** a sidecar document with presentations and child `smd` paths is read with `ContainerFile.container(from:)`
- **THEN** the result equals the sidecar's container

#### Scenario: a sidecar with rules read as a container
- **WHEN** a sidecar document whose `<container>` ends in a `<rules>` element is read with `ContainerFile.container(from:)`
- **THEN** the result equals the sidecar's container

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`theRepositoryReaderReadsASidecarAsItsContainer`, `aSidecarWithRulesSurvivesTheFile`).

### Requirement: Every written container can be read back
For every `Container` value `c`, reading `ContainerFile.data(for: c)` SHALL succeed, both without
an expected id and expecting `c.id`. The writer SHALL NOT throw and SHALL NOT validate the
container: the model cannot hold a value the reader refuses, because every id, item id, title and
entry kind the reader checks is a checked type (see the `container-model` spec). The writer SHALL
remove every character outside XML 1.0's `Char` production from every other text and attribute
value it writes, because no escape can carry one, so every document it produces is well-formed.

#### Scenario: a control character in an outline
- **WHEN** a container whose outline holds U+0001 between two letters is written and the result is read
- **THEN** the read succeeds, and the outline read is the two letters

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`everyWrittenContainerReadsBack`).
