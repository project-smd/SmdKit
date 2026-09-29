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
`ContainerFile.data(for:)` SHALL produce a UTF-8 XML 1.0 document, pretty-printed, with empty
elements in their compact form and ending in a newline, whose root is
`<container format="1" id="<id>" type="<type>">`, with `listed="false"` added only when the
container is not listed. `ContainerFile.format` SHALL be 1 and `ContainerFile.fileName(for:)` SHALL
be the id followed by `.xml`.

#### Scenario: a listed container
- **WHEN** a listed serial is written
- **THEN** the root element carries `format`, `id` and `type` and no `listed` attribute

#### Scenario: an unlisted container
- **WHEN** a series with `listed` false is written
- **THEN** the root element carries `listed="false"`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`). The order itself is not yet measured; the tests check the elements and the round trip.

### Requirement: Items are written as the sidecar spells them, with children and refs by id
Each entry SHALL be written as `<item>`. A ref SHALL be written with only a `ref` attribute, whose
value is the item id for a ref within the container and `<container id>#<item id>` for a ref into
another container. Any other entry SHALL carry `type`, `id`, `optional="true"` only when optional,
`container="<id>"` when it names a child, then its `<title>`, `<outline>` and external references.
The document SHALL NOT contain `<presentation>` elements or `smd` attributes.

#### Scenario: a child container item
- **WHEN** a series whose sequence holds a child season with item id `season-14` is written
- **THEN** the item is written with `type="container"`, `id="season-14"` and `container` set to the season's id

#### Scenario: a ref into another container
- **WHEN** an extra is a ref to item `s14-talons` of the container with id `0b9e8d7c6f5a4b3c`
- **THEN** the item is written as `<item ref="0b9e8d7c6f5a4b3c#s14-talons"/>`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

### Requirement: A written container reads back equal
`ContainerFile.container(from: ContainerFile.data(for: c))` SHALL equal `c` for a container `c`
that is representable in the document, meaning: every id in it passes `ContainerID.init?(_:)`; its
title is non-empty; every optional text field is either nil or non-empty, has no leading or trailing
whitespace, no carriage return and no character XML 1.0 cannot carry; `yearInTitle` is true only
with a year; a default alternative is set only with alternatives; its entries of type `container`
all name a child and its other entries name none; and its refs carry no id and name items with no
`#` in them. Outside those conditions a value comes back different — an empty optional text as
nil, `yearInTitle` without a year as false, a default without alternatives as nil, a ref's id
dropped, a carriage return and line feed as a line feed — or fails to read.

#### Scenario: the worked example
- **WHEN** a serial with three alternatives, two features, three sequences including one of refs, an extras anchor and a cross-container ref is written and read back with its own id expected
- **THEN** the value read equals the value written

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

### Requirement: Text is trimmed on read
The reader SHALL trim leading and trailing whitespace and newlines from the text of every element
it reads as text — titles, type labels and outlines — so a document may indent that text freely,
and whitespace at either end of such a value does not survive a round trip. The text of `<year>`
SHALL NOT be trimmed, so a year written with surrounding whitespace throws `invalidText`.

#### Scenario: surrounding whitespace
- **WHEN** a container titled with a leading and a trailing space is written and read back
- **THEN** the title read has neither space

Pinned by: nothing yet.

### Requirement: The writer accepts values the reader refuses
`ContainerFile.data(for:)` SHALL NOT validate the container. A container with an empty title is
written without a `<title>`; an entry of type `container` with no child is written without a
`container` attribute; an entry of another type that names a child is written with one; an id made
with `ContainerID(rawValue:)` that is not sixteen lowercase hex characters is written as given; and
a ref naming an empty item id, or an item id containing `#`, is written as given. The reader refuses
every one of these documents, so each value is written to a file that cannot be read back, which is
tracked as a defect in https://github.com/project-smd/SmdKit/issues/7.

#### Scenario: an empty title
- **WHEN** a container titled with the empty string is written and the result is read
- **THEN** the read fails with `missingElement(element: "container", child: "title")`

#### Scenario: a container item with no child
- **WHEN** a container whose sequence holds `Entry(id: "a", type: .container)` is written and the result is read
- **THEN** the read fails with `missingAttribute(element: "item", attribute: "container")`

Pinned by: nothing yet.

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
that is neither `true` nor `false`; `invalidText` for a `<year>` whose text is not an integer; and
`missingElement` for a container with no `<title>`. Provider, entry type and feature type SHALL be
read as given, since they are open.

#### Scenario: an unknown container type
- **WHEN** an otherwise valid container document with `type="box"` is read
- **THEN** the read throws `invalidValue(element: "container", attribute: "type", value: "box")`

#### Scenario: no title
- **WHEN** an otherwise valid container document with no `<title>` is read
- **THEN** the read throws `missingElement(element: "container", child: "title")`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader enforces the item forms
An `<item>` with a `ref` attribute SHALL carry neither `id` nor `type`, else the reader throws
`refWithIdentity`. A ref of the form `<a>#<b>` SHALL have a valid container id before the `#` and a
non-empty item id after it, and a ref SHALL NOT be empty, else `invalidValue`. Any other item SHALL
carry `type` and `id`. A `container` attribute SHALL appear only on an item of type `container` and
SHALL be a valid id, else `invalidValue`; an item of type `container` without one SHALL throw
`missingAttribute`.

#### Scenario: a ref with an id
- **WHEN** an item with both `ref="part1"` and an `id` is read
- **THEN** the read throws `refWithIdentity("part1")`

#### Scenario: a container item with no child
- **WHEN** an item with `type="container"` and no `container` attribute is read
- **THEN** the read throws `missingAttribute(element: "item", attribute: "container")`

#### Scenario: an episode naming a child
- **WHEN** an item with `type="episode"` and a `container` attribute is read
- **THEN** the read throws `invalidValue` for the `container` attribute

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`).

### Requirement: The reader ignores what it does not know
The reader SHALL ignore elements and attributes it does not read, including `<presentation>`
elements and `smd` attributes, so a sidecar read with `ContainerFile` yields its container
unchanged. It SHALL NOT check that local ids are unique or slugs, that an alternative's sequence
exists, that the default names an alternative, or that the extras anchor names an item.

#### Scenario: a sidecar read as a container
- **WHEN** a sidecar document with presentations and child `smd` paths is read with `ContainerFile.container(from:)`
- **THEN** the result equals the sidecar's container

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`theRepositoryReaderReadsASidecarAsItsContainer`).
