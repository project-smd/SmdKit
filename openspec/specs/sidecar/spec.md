<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Sidecar

## Purpose

The `SmdSidecar` target is the `.smd` as a library keeps it. A `Sidecar` is a `Container` plus the
facts that are the library's own: which file holds each presentation of each item, and where each
child container's sidecar is. `SidecarFile` reads and writes it as the repository's container
document with those facts added, so the repository reader reads a sidecar and sees its container.
Writing has two modes: generate, from the value alone, and update, which changes only the library's
facts in a document already on disk.

Documentation: [README](../../../README.md), and `StructuredContainers.md` in
[smddb](https://github.com/project-smd/smddb).

## Requirements

### Requirement: A sidecar is the container document plus presentations and child paths
`SidecarFile.data(for:)` SHALL write the container as `ContainerFile.data(for:)` does and then add,
under each item that has presentations, one `<presentation>` per presentation in order, and on each
child container item whose child has a path in `children`, an `smd` attribute holding that path. A
presentation SHALL be written with `alternative`, `profile` and `file` attributes, each only when
set, then a `<source disc playlist>` when it has a source, one `<track feature audio subtitle>` per
track mapping with `audio` and `subtitle` only when set, and one `<chapter index title>` per
chapter. `SidecarFile.fileName` SHALL be `container.smd`.

#### Scenario: a presentation with a source, a track and chapters
- **WHEN** a sidecar whose item `part1` has a presentation with a file, a source disc and playlist, a commentary on audio stream 3 and two named chapters is written
- **THEN** that item holds a `<presentation>` with the `file` attribute, a `<source>` with the disc and playlist, a `<track>` with `feature` and `audio="3"`, and a `<chapter>` per chapter

#### Scenario: a child with a sidecar path
- **WHEN** a sidecar maps its child container's id to a relative path and is written
- **THEN** the child's item carries `smd` with that path after its `container` attribute

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`).

### Requirement: The repository reader reads a sidecar as its container
A document written by `SidecarFile` SHALL read with `ContainerFile.container(from:)` as exactly the
sidecar's container, the library's facts ignored, for a container representable in the document
as the `container-file` spec's round-trip requirement defines it.

#### Scenario: reading a sidecar with the repository reader
- **WHEN** a sidecar with presentations and a child path is written and the result is read with `ContainerFile.container(from:)`
- **THEN** the container read equals the sidecar's container

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`theRepositoryReaderReadsASidecarAsItsContainer`).

### Requirement: Reading takes the container first and the library's facts from the same document
`SidecarFile.sidecar(from:)` SHALL read the container with `ContainerFile.container(from:)`, so
every refusal of that reader applies, and then, over the items of every sequence and then the
extras, SHALL record the `smd` path of each item whose `container` attribute is a valid id, and the
presentations of each item with an id that has at least one. A sidecar written with
`SidecarFile.data(for:)` SHALL therefore read back equal when its container is representable, every
`children` entry names a child the container holds, and no item maps to an empty list. A presentation SHALL require `file`;
a `<source>` SHALL require `disc` and `playlist`; a `<track>` SHALL require `feature` and read
`audio` and `subtitle` as optional integers; a `<chapter>` SHALL require an integer `index` and a
`title`. A missing required attribute SHALL throw `ContainerFileError.missingAttribute` and a
non-integer SHALL throw `ContainerFileError.invalidValue`.

#### Scenario: a sidecar survives the file
- **WHEN** a sidecar with presentations of three kinds on one item, one on an extra, and a child path is written with `SidecarFile.data(for:)` and read back
- **THEN** the sidecar read equals the sidecar written

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`).

### Requirement: An empty presentation list is not recorded
Reading SHALL add an entry to `presentations` only for an item with at least one `<presentation>`,
so a sidecar that maps an item to an empty list reads back without that entry and is not equal to
the value written.

#### Scenario: an item with an empty presentation list
- **WHEN** a sidecar maps an item to an empty presentation list and is written and read back
- **THEN** the sidecar read has no entry for that item

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anEmptyPresentationListIsNotRecorded`).

### Requirement: A presentation must belong to an item the container has
Writing, in either mode, SHALL throw `SidecarFileError.unknownItem` naming the id when
`presentations` has an entry for an id that is neither an item in the document nor an item of the
container's sequences or extras. A `children` entry for a container no item holds SHALL be dropped
silently.

#### Scenario: a presentation for a missing item
- **WHEN** a sidecar maps presentations to item `part9`, which the container does not declare, and is written
- **THEN** the write throws `unknownItem("part9")`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aPresentationNeedsAnItemToHoldIt`).

### Requirement: An update refuses a document for another container
`SidecarFile.data(for:updating:)` SHALL read the existing document with
`ContainerFile.container(from:expecting:)` expecting the sidecar's container id, and SHALL throw
the reader's error, including `idMismatch`, when the document is unreadable or describes a
different container.

#### Scenario: updating another container's sidecar
- **WHEN** a sidecar is written as an update over a document whose container id is different
- **THEN** the write throws a `ContainerFileError`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateRefusesADifferentContainer`).

### Requirement: An update changes only the library's facts
An update SHALL leave the existing document's comments, element order and the container's own
fields as they are, and SHALL NOT add or change alternatives, features, titles or other container
fields even when the value differs. It SHALL replace the `<presentation>` elements of every item
that has an entry in `presentations` with the value's, set the `smd` attribute of every child
container item whose child has a path in `children`, and append each item of the value that has an
id the document lacks, spelled as `ContainerFile` spells it, to the end of the sequence with the
same id, or to the extras for an extra. A sequence the document lacks SHALL be created, with its
`id` and no other attribute, only when one of its items is appended, before the document's
`<extras>` or at the end when there is none; missing extras SHALL likewise be created at the end only
when an extra is appended. A sequence or extras holding only refs is never created, since a ref has
no id to be missing. A container that has drifted from the value is left for a validator to report.

#### Scenario: a hand-kept document
- **WHEN** a sidecar is written as an update over a document with a comment, a hand-edited title, one alternative, and item `part1` holding an old presentation, while the value has two alternatives, a new presentation for `part1`, a second part, an extra, and a child container item with a sidecar path
- **THEN** the comment and the hand-edited title remain, no alternative is added, `part1`'s old presentation is replaced, the second part is appended to its sequence, extras are created for the extra, and the child carries its `smd` path

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateChangesOnlyTheLibrarysFacts`).

### Requirement: An update removes a library fact the value no longer has
An update SHALL remove the `<presentation>` elements of every item whose id is an item of the
value's sequences or extras and has no entry in `presentations`, and the `smd` attribute of every
child container item whose child the value's sequences or extras hold and has no path in
`children`. An item the document has and the value's container does not declare SHALL keep its
presentations and `smd` attribute, since it is drift left for a validator to report.

#### Scenario: a presentation removed from the value
- **WHEN** a document has presentations for `part1` and `part2`, and is updated with a sidecar whose container declares both parts and whose `presentations` has an entry for `part1` only
- **THEN** reading the result yields no presentation for `part2`

#### Scenario: a child path removed from the value
- **WHEN** a document has an `smd` path on a child the sidecar's container holds, and is updated with a sidecar whose `children` is empty
- **THEN** reading the result yields no path for that child

#### Scenario: an item only the document has
- **WHEN** a document has a presentation on an item the sidecar's container does not declare, and is updated
- **THEN** reading the result still yields that item's presentation

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateRemovesFactsTheValueNoLongerHas`).

### Requirement: A sidecar is written as the repository file would be
Both modes SHALL write the byte form `ContainerFile.data(for:)` writes, on every platform, even
when the document was parsed from data with another declaration or indentation: the declaration
carries no `standalone` declaration, and whitespace-only text between elements is replaced by the
writer's indentation. An element holding text beside its elements is mixed content and SHALL be
written as it stands, with no whitespace added or removed inside it. An attribute value's tab, line
feed and carriage return SHALL be written as character references, so they read back unchanged.

#### Scenario: a generated document
- **WHEN** a sidecar with no presentations and no child paths is written from the value
- **THEN** the bytes equal those the repository writer writes for its container

#### Scenario: an updated document
- **WHEN** that sidecar is written as an update over its container's document, declared standalone and indented by two spaces
- **THEN** the declaration carries no `standalone` attribute, and the bytes equal those the repository writer writes for its container

#### Scenario: mixed content
- **WHEN** a sidecar is written as an update over a document whose outline holds text around an element
- **THEN** the outline is written as it stood

#### Scenario: whitespace in a presentation
- **WHEN** a presentation whose file name holds a tab, a line feed and a carriage return is written and read back
- **THEN** the file name read is the one written

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarIsWrittenAsTheRepositoryFileWouldBe`, `anUpdateKeepsMixedContentAsItStands`, `aPresentationKeepsWhitespaceInItsAttributes`).

### Requirement: A presentation is named by its alternative, then its profile
`Sidecar.displayName(of:)` SHALL return, for a presentation with an alternative, that alternative's
title in the container, or the alternative id when the container has no such alternative or it has
no title; otherwise the presentation's profile; otherwise `nil`. `Sidecar.files` SHALL be the
`file` of every presentation of every item, with no order guaranteed.

#### Scenario: the three kinds of presentation
- **WHEN** an item has an unqualified presentation, one with profile `mobile`, and one for the alternative titled `Updated special effects`
- **THEN** their display names are `nil`, `mobile` and `Updated special effects`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`displayNamesComeFromTheContainer`).
