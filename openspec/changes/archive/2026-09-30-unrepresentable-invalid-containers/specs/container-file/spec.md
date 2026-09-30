<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

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

Pinned by: nothing yet.

## MODIFIED Requirements

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`containerSurvivesTheFile`, `childrenAreNamedByIdentity`).

### Requirement: A written container reads back equal
`ContainerFile.container(from: ContainerFile.data(for: c))` SHALL equal `c` when every string in
`c` other than a `ContainerID` or an `ItemID` holds only characters XML 1.0 can carry and no
carriage return; when every such string written as an attribute holds no tab or line feed either;
when every optional text field is either nil or non-empty with no leading or trailing whitespace;
when `yearInTitle` is true only with a year; and when a default alternative is set only with
alternatives. Outside those conditions the value SHALL still be read back, per "Every written
container can be read back", but it comes back different: an empty optional text as nil, text with
surrounding whitespace trimmed, a carriage return and line feed as a line feed, a tab or line break
in an attribute as a space, a character XML 1.0 cannot carry removed, `yearInTitle` without a year
as false, and a default without alternatives as nil.

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
- **WHEN** a container whose outline has a leading and a trailing space is written and read back
- **THEN** the outline read has neither space

Pinned by: nothing yet.

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`). A blank title is not yet measured.

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`fileRefusesWhatItCannotRead`). An item id that `ItemID` refuses is not yet measured.

## REMOVED Requirements

### Requirement: The writer accepts values the reader refuses
**Reason**: The values it described can no longer be built, and the writer removes the characters XML 1.0 cannot carry, so every document it writes reads back.
**Migration**: See "Every written container can be read back".
