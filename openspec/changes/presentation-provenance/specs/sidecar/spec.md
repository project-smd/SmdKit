<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: A sidecar is the container document plus presentations and child paths
`SidecarFile.data(for:)` SHALL write the container as `ContainerFile.data(for:)` does and then add,
under each item that has binding rules, one empty `<rules>` element per binding, in order, with its
`binding`, `path` and `activeVersion` attributes; under each item that has presentations, one
`<presentation>` per presentation in order, after its binding rules; on each child container item
whose child has a path in `children`, an `smd` attribute holding that path; and, when the sidecar has
`rules`, an empty `<rules>` element with its `path` and `activeVersion` attributes as the last child of
`<container>`. A presentation SHALL be written with `alternative`, `profile` and `file` attributes,
each only when set, then a `<source>` when it has a source, then a `<transform>` when it has one, one
`<track feature audio subtitle>` per track mapping with `audio` and `subtitle` only when set, and one
`<chapter index title>` per chapter. `SidecarFile.fileName` SHALL be `container.smd`.

#### Scenario: a presentation with a source, a track and chapters
- **WHEN** a sidecar whose item `part1` has a presentation with a file, a source naming a binding with one whole segment of a source with a natural key, a commentary on audio stream 3 and two named chapters is written
- **THEN** that item holds a `<presentation>` with the `file` attribute, a `<source>` with the `binding` holding one `<segment>` with the key's `scheme` and `value`, a `<track>` with `feature` and `audio="3"`, and a `<chapter>` per chapter

#### Scenario: a child with a sidecar path
- **WHEN** a sidecar maps its child container's id to a relative path and is written
- **THEN** the child's item carries `smd` with that path after its `container` attribute

#### Scenario: a sidecar with rules
- **WHEN** a sidecar with extras and `rules` naming the path `rules` and active version 4 is written
- **THEN** the last child of `<container>`, after the extras, is `<rules path="rules" activeVersion="4"/>`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`, `aSidecarWithRulesSurvivesTheFile`).

### Requirement: Reading takes the container first and the library's facts from the same document
`SidecarFile.sidecar(from:)` SHALL read the container with `ContainerFile.container(from:)`, so
every refusal of that reader applies, and then, over the items of every sequence and then the
extras, SHALL record the `smd` path of each item whose `container` attribute is a valid id, the
presentations of each item with an id that has at least one, and the binding rules of each item with
an id that has at least one; and SHALL record as `rules` the reference the `<rules>` element that is
a child of the root `<container>` makes, when there is one. A `<rules>` element that is a child of an
item SHALL be read as a binding's rules, never as the container's. A sidecar written with
`SidecarFile.data(for:)` SHALL therefore read back equal when its container is representable, every
`children` entry names a child the container holds, and no item maps to an empty list. A presentation
SHALL require `file`; its `<source>` and `<transform>` SHALL be read as the requirements on provenance
below describe; a `<track>` SHALL require `feature` and read `audio` and `subtitle` as optional
integers; a `<chapter>` SHALL require an integer `index` and a `title`; the container's `<rules>`
SHALL require a non-empty `path` and an integer `activeVersion` of at least 1. A missing required
attribute SHALL throw `ContainerFileError.missingAttribute`, and a non-integer, an empty `path` or an
`activeVersion` below 1 SHALL throw `ContainerFileError.invalidValue`.

#### Scenario: a sidecar survives the file
- **WHEN** a sidecar with presentations of three kinds on one item, one on an extra, a child path and rules is written with `SidecarFile.data(for:)` and read back
- **THEN** the sidecar read equals the sidecar written

#### Scenario: rules inside an item are not the container's
- **WHEN** a sidecar document has a `<rules>` element naming a binding inside an `<item>` and none as a child of `<container>`
- **THEN** the sidecar read has no rules, and the item has that binding's rules

#### Scenario: an empty sidecar
- **WHEN** empty data is read with `SidecarFile.sidecar(from:)`, or given as the document to update or to set rules in
- **THEN** each throws `ContainerFileError.malformed("the document is empty")`

#### Scenario: a rules reference that names nothing
- **WHEN** a sidecar document's `<container>` has a `<rules>` element with no `path`, or with `activeVersion="0"`, or with `activeVersion="four"`
- **THEN** reading throws `missingAttribute` for the first and `invalidValue` for the other two

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`, `aSidecarWithRulesSurvivesTheFile`, `anEmptySidecarIsMalformed`, `aRulesReferenceThatNamesNothingIsRefused`). Rules inside an item read as a binding's are pinned by nothing yet.

### Requirement: An update changes only the library's facts
An update SHALL leave the existing document's comments, element order and the container's own
fields as they are, and SHALL NOT add or change alternatives, features, titles or other container
fields even when the value differs. It SHALL leave the document's `<rules>` element, and every
item's binding `<rules>` elements, as they stand, or their absence, whatever the value's `rules` and
`bindingRules` say: which rules a container or a binding uses is authored, and an update's caller is
a placement that knows nothing of them. It SHALL replace the `<presentation>` elements of every item
that has an entry in `presentations` with the value's, each whole, its `<source>` and `<transform>`
included, set the `smd` attribute of every child container item whose child has a path in
`children`, and append each item of the value that has an id the document lacks, spelled as
`ContainerFile` spells it, to the end of the sequence with the same id, or to the extras for an
extra. A sequence the document lacks SHALL be created, with its `id` and no other attribute, only
when one of its items is appended, before the document's `<extras>` or at the end when there is none;
missing extras SHALL likewise be created at the end only when an extra is appended. A sequence or
extras holding only refs is never created, since a ref has no id to be missing. A container that has
drifted from the value is left for a validator to report.

#### Scenario: a hand-kept document
- **WHEN** a sidecar is written as an update over a document with a comment, a hand-edited title, one alternative, and item `part1` holding an old presentation, while the value has two alternatives, a new presentation for `part1`, a second part, an extra, and a child container item with a sidecar path
- **THEN** the comment and the hand-edited title remain, no alternative is added, `part1`'s old presentation is replaced, the second part is appended to its sequence, extras are created for the extra, and the child carries its `smd` path

#### Scenario: a placement over a container with rules
- **WHEN** a document whose `<rules>` element names active version 2 of `rules`, with a comment before it, is updated with a sidecar that has a new presentation and no `rules`
- **THEN** the result holds the same `<rules>` element and the comment before it, and the new presentation

#### Scenario: an update does not add rules
- **WHEN** a document with no `<rules>` element is updated with a sidecar that has `rules`
- **THEN** the result holds no `<rules>` element

#### Scenario: a placement over an item with a binding's rules
- **WHEN** a document whose item holds a binding's `<rules>` and a presentation is updated with a sidecar that replaces the item's presentation and has no binding rules
- **THEN** the item still holds the binding's `<rules>`, and the new presentation in place of the old

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateChangesOnlyTheLibrarysFacts`, `anUpdateLeavesTheRulesAsTheyStand`). A placement over an item with a binding's rules is pinned by nothing yet.

### Requirement: SidecarRules names a version of a container's rules
`SidecarRules` SHALL hold a `path`, the folder of every version of the rules relative to the
sidecar's folder, and an `activeVersion`, the version in force, from 1. Its `file(version:)` SHALL be
`<path>/<version>.xml`, any version's file relative to the sidecar's folder, and its `activeFile` the
file of the active version. The package SHALL NOT read the folder or any file in it: which versions
exist, and what their files say, are the library's server's.

#### Scenario: where a version is
- **WHEN** a sidecar's rules name the path `rules` and active version 4
- **THEN** their `activeFile` is `rules/4.xml`, and their `file(version: 2)` is `rules/2.xml`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aRulesReferenceNamesItsFile`).

## ADDED Requirements

### Requirement: A presentation names the binding it was made from, with a copy of its segments
A presentation's `source`, when it has one, SHALL be written as one `<source>` element with its
`binding`, holding one `<segment>` per segment, in order: `scheme` and `value` when the segment's
source has a natural key, and neither when it has none; and `from` and `to`, the first and last
chapters it spans counted from one, when the segment is part of its source, and neither when it is the
whole. Reading SHALL require `binding` to be a UUID, at least one `<segment>`, `scheme` and `value`
together or neither, and `from` and `to` together or neither, as integers of at least 1 with `from` no
greater than `to`. A missing attribute or a lone one of a pair SHALL throw
`ContainerFileError.missingAttribute`, no `<segment>` SHALL throw `ContainerFileError.missingElement`,
and any other value outside those bounds, or more than one `<source>` on a presentation, SHALL throw
`ContainerFileError.invalidValue`. The package SHALL NOT read a key's scheme or value.

#### Scenario: a film across two discs, and an episode cut from a title
- **WHEN** a presentation made from a binding of two whole segments of sources with natural keys, and another made from a binding of chapter 2 of a source with no natural key, are written and read back
- **THEN** the first's `<source>` holds two `<segment>` elements with their keys in order, the second's one `<segment from="2" to="2"/>`, and both read back equal

#### Scenario: a span that runs backwards
- **WHEN** a presentation's `<segment>` has `from="3"` and `to="2"`
- **THEN** reading throws `invalidValue`

Pinned by: nothing yet.

### Requirement: A presentation names every set of rules that made it
A presentation's `transform`, when it has one, SHALL be written as one `<transform>` element with its
`ruleset` and `version`, holding, in order, nearest first, one `<layer>` per set of rules — naming
exactly one of a `binding` and a `container`, then its `version` and, when set, its `digest`. Reading
SHALL require a non-empty `ruleset` and an integer `version` of at least 1 on `<transform>`; and on
each `<layer>` exactly one of `binding`, a UUID, and `container`, a valid container id, and an integer
`version` of at least 1. A missing attribute SHALL throw `ContainerFileError.missingAttribute`, and a
layer naming both subjects, any other value outside those bounds, or more than one `<transform>` on a
presentation, SHALL throw `ContainerFileError.invalidValue`. The package SHALL NOT read what a
ruleset, a version or a digest means.

#### Scenario: a presentation made through a binding's rules and a season's
- **WHEN** a presentation made by `household` version 7, through its binding's rules at version 2 and a season's at version 4, is written and read back
- **THEN** it holds a `<transform ruleset="household" version="7">` with a `<layer>` naming the binding, then one naming the season, and reads back equal

#### Scenario: a layer of two subjects
- **WHEN** a presentation's `<layer>` names both a `binding` and a `container`
- **THEN** reading throws `invalidValue`

Pinned by: nothing yet.

### Requirement: An item names the rules of each binding that has its own
An item's binding rules SHALL be read from its `<rules>` children, each requiring a `binding` that is
a UUID, a non-empty `path` and an integer `activeVersion` of at least 1, and naming the binding's
folder of rule versions and the version in force as `SidecarRules` names a container's. Two `<rules>` on one
item naming the same binding SHALL throw `SidecarFileError.multipleRules`, and one holding an element
SHALL throw `SidecarFileError.inlineRules`. The repository file SHALL hold none.

#### Scenario: a binding's rules survive the file
- **WHEN** a sidecar whose item has rules for one binding, at active version 2 of the folder `rules/bindings/<binding>`, is written and read back
- **THEN** the item holds `<rules>` with the binding, path and active version before its presentations, and reads back equal

#### Scenario: two for one binding
- **WHEN** an item has two `<rules>` naming the same binding
- **THEN** reading throws `multipleRules`

Pinned by: nothing yet.

### Requirement: Setting a binding's rules changes only those rules
`SidecarFile.data(settingRules:binding:item:in:)` SHALL read the document's container with
`ContainerFile.container(from:)`, so every refusal of that reader applies, and SHALL return the
document with the item's `<rules>` for that binding replaced by the given reference, added before the
item's presentations when it had none, or removed when the rules given are nil. An item the container
does not have SHALL throw `SidecarFileError.unknownItem`. It SHALL change nothing else.

#### Scenario: a binding's rules move to their next version
- **WHEN** a document whose item has a comment, a presentation and rules for a binding at active version 2 has that binding's rules set to active version 3
- **THEN** reading the result yields the binding's rules at active version 3, the same presentation, and the comment is still there

Pinned by: nothing yet.
