<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

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
