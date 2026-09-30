<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: A sidecar is the container document plus presentations and child paths
`SidecarFile.data(for:)` SHALL write the container as `ContainerFile.data(for:)` does and then add,
under each item that has presentations, one `<presentation>` per presentation in order, on each
child container item whose child has a path in `children`, an `smd` attribute holding that path,
and, when the sidecar has `rules`, its `<rules>` element as the last child of `<container>`. A
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

#### Scenario: a sidecar with rules
- **WHEN** a sidecar with extras and `rules` holding a `<rules>` element with one child is written
- **THEN** the `<rules>` element is the last child of `<container>`, after the extras, holding that child

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`); a sidecar with rules is pinned by nothing yet.

### Requirement: The repository reader reads a sidecar as its container
A document written by `SidecarFile` SHALL read with `ContainerFile.container(from:)` as exactly the
sidecar's container, the library's facts — presentations, child paths and rules — ignored, for a
container representable in the document as the `container-file` spec's round-trip requirement
defines it.

#### Scenario: reading a sidecar with the repository reader
- **WHEN** a sidecar with presentations, a child path and rules is written and the result is read with `ContainerFile.container(from:)`
- **THEN** the container read equals the sidecar's container

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`theRepositoryReaderReadsASidecarAsItsContainer`); rules are pinned by nothing yet.

### Requirement: Reading takes the container first and the library's facts from the same document
`SidecarFile.sidecar(from:)` SHALL read the container with `ContainerFile.container(from:)`, so
every refusal of that reader applies, and then, over the items of every sequence and then the
extras, SHALL record the `smd` path of each item whose `container` attribute is a valid id, and the
presentations of each item with an id that has at least one; and SHALL record as `rules` the
`<rules>` element that is a child of the root `<container>`, when there is one. A `<rules>` element
anywhere else SHALL be ignored. A sidecar written with `SidecarFile.data(for:)` SHALL therefore read
back equal when its container is representable, every `children` entry names a child the container
holds, and no item maps to an empty list. A presentation SHALL require `file`; a `<source>` SHALL
require `disc` and `playlist`; a `<track>` SHALL require `feature` and read `audio` and `subtitle` as
optional integers; a `<chapter>` SHALL require an integer `index` and a `title`. A missing required
attribute SHALL throw `ContainerFileError.missingAttribute` and a non-integer SHALL throw
`ContainerFileError.invalidValue`.

#### Scenario: a sidecar survives the file
- **WHEN** a sidecar with presentations of three kinds on one item, one on an extra, a child path and rules is written with `SidecarFile.data(for:)` and read back
- **THEN** the sidecar read equals the sidecar written

#### Scenario: rules inside an item are not the container's
- **WHEN** a sidecar document has a `<rules>` element inside an `<item>` and none as a child of `<container>`
- **THEN** the sidecar read has no rules

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`); rules are pinned by nothing yet.

### Requirement: An update changes only the library's facts
An update SHALL leave the existing document's comments, element order and the container's own
fields as they are, and SHALL NOT add or change alternatives, features, titles or other container
fields even when the value differs. It SHALL leave the document's `<rules>` element as it stands,
or its absence, whatever the value's `rules` says: rules are authored, and an update's caller is a
placement that knows nothing of them. It SHALL replace the `<presentation>` elements of every item
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

#### Scenario: a placement over a container with rules
- **WHEN** a document whose `<rules>` element holds a comment and one rule is updated with a sidecar that has a new presentation and no `rules`
- **THEN** the result holds the same `<rules>` element, comment and rule included, and the new presentation

#### Scenario: an update does not add rules
- **WHEN** a document with no `<rules>` element is updated with a sidecar that has `rules`
- **THEN** the result holds no `<rules>` element

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateChangesOnlyTheLibrarysFacts`); rules are pinned by nothing yet.

## ADDED Requirements

### Requirement: SidecarRules holds one rules element in one canonical form
`SidecarRules(xml:)` SHALL succeed for text that is well-formed XML whose one root element is named
`rules`, and SHALL return nil otherwise. It SHALL hold, as `xml`, the element as the sidecar writer
writes an element at the top level — four spaces of indentation for each element enclosing a child,
counted from `<rules>` itself, comments kept, whitespace-only text between elements dropped, mixed
content as it stands — with no XML declaration and no trailing newline. Two spellings of one element
that differ only in that whitespace SHALL hold the same `xml` and compare equal. The package SHALL NOT
read the rules inside the element: their elements and attributes are kept as written, whatever they
are.

#### Scenario: two spellings of one element
- **WHEN** `SidecarRules(xml:)` is given a `<rules>` element holding a comment and a `<video>` element, once indented by two spaces and once on one line
- **THEN** both succeed, hold the same `xml`, and compare equal

#### Scenario: not a rules element
- **WHEN** `SidecarRules(xml:)` is given `<rule/>`, or `<rules>` with no closing tag
- **THEN** it returns nil both times

Pinned by: nothing yet.

### Requirement: A sidecar holds at most one rules element
`SidecarFile.sidecar(from:)` SHALL throw `SidecarFileError.multipleRules` when the root
`<container>` has more than one `<rules>` child, since which one applies has no answer.

#### Scenario: two rules elements
- **WHEN** a sidecar document's `<container>` has two `<rules>` children
- **THEN** reading throws `multipleRules`

Pinned by: nothing yet.

### Requirement: Setting a sidecar's rules changes only its rules
`SidecarFile.data(settingRules:in:)` SHALL read the document's container with
`ContainerFile.container(from:)`, so every refusal of that reader applies, and SHALL return the
document with its `<rules>` child of `<container>` replaced by the given rules, added as the last
child of `<container>` when it had none, or removed when the rules given are nil. It SHALL change
nothing else: comments, order, the container's fields, presentations and child paths stay as they
are, and the result is written in the byte form every sidecar write produces.

#### Scenario: rules replaced
- **WHEN** a document with a comment, a presentation and a `<rules>` element has its rules set to a different element
- **THEN** reading the result yields the new rules, the same presentation, and the comment is still there

#### Scenario: rules removed
- **WHEN** a document with a `<rules>` element has its rules set to nil
- **THEN** reading the result yields no rules, and everything else reads as before

Pinned by: nothing yet.
