<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: A sidecar is the container document plus presentations and child paths
`SidecarFile.data(for:)` SHALL write the container as `ContainerFile.data(for:)` does and then add,
under each item that has presentations, one `<presentation>` per presentation in order, on each
child container item whose child has a path in `children`, an `smd` attribute holding that path,
and, when the sidecar has `rules`, an empty `<rules>` element with its `path` and `version`
attributes as the last child of `<container>`. A presentation SHALL be written with `alternative`,
`profile` and `file` attributes, each only when set, then one `<source>` per source segment, in order,
then a `<madeBy>` when it has a derivation, one `<track feature audio subtitle>` per track mapping
with `audio` and `subtitle` only when set, and one `<chapter index title>` per chapter.
`SidecarFile.fileName` SHALL be `container.smd`.

#### Scenario: a presentation with a source, a track and chapters
- **WHEN** a sidecar whose item `part1` has a presentation with a file, one whole segment of a source with a natural key, a commentary on audio stream 3 and two named chapters is written
- **THEN** that item holds a `<presentation>` with the `file` attribute, a `<source>` with the key's `scheme` and `value`, a `<track>` with `feature` and `audio="3"`, and a `<chapter>` per chapter

#### Scenario: a child with a sidecar path
- **WHEN** a sidecar maps its child container's id to a relative path and is written
- **THEN** the child's item carries `smd` with that path after its `container` attribute

#### Scenario: a sidecar with rules
- **WHEN** a sidecar with extras and `rules` naming the path `rules` and version 4 is written
- **THEN** the last child of `<container>`, after the extras, is `<rules path="rules" version="4"/>`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`, `aSidecarWithRulesSurvivesTheFile`).

### Requirement: Reading takes the container first and the library's facts from the same document
`SidecarFile.sidecar(from:)` SHALL read the container with `ContainerFile.container(from:)`, so
every refusal of that reader applies, and then, over the items of every sequence and then the
extras, SHALL record the `smd` path of each item whose `container` attribute is a valid id, and the
presentations of each item with an id that has at least one; and SHALL record as `rules` the
reference the `<rules>` element that is a child of the root `<container>` makes, when there is one.
A `<rules>` element anywhere else SHALL be ignored. A sidecar written with `SidecarFile.data(for:)`
SHALL therefore read back equal when its container is representable, every `children` entry names a
child the container holds, and no item maps to an empty list. A presentation SHALL require `file`; its
`<source>` and `<madeBy>` elements SHALL be read as the requirements on provenance below describe; a
`<track>` SHALL require `feature` and read `audio` and `subtitle` as optional integers; a `<chapter>`
SHALL require an integer `index` and a `title`; the container's `<rules>` SHALL require a non-empty
`path` and an integer `version` of at least 1. A missing required attribute SHALL throw
`ContainerFileError.missingAttribute`, and a non-integer, an empty `path` or a `version` below 1 SHALL
throw `ContainerFileError.invalidValue`.

#### Scenario: a sidecar survives the file
- **WHEN** a sidecar with presentations of three kinds on one item, one on an extra, a child path and rules is written with `SidecarFile.data(for:)` and read back
- **THEN** the sidecar read equals the sidecar written

#### Scenario: rules inside an item are not the container's
- **WHEN** a sidecar document has a `<rules>` element inside an `<item>` and none as a child of `<container>`
- **THEN** the sidecar read has no rules

#### Scenario: an empty sidecar
- **WHEN** empty data is read with `SidecarFile.sidecar(from:)`, or given as the document to update or to set rules in
- **THEN** each throws `ContainerFileError.malformed("the document is empty")`

#### Scenario: a rules reference that names nothing
- **WHEN** a sidecar document's `<container>` has a `<rules>` element with no `path`, or with `version="0"`, or with `version="four"`
- **THEN** reading throws `missingAttribute` for the first and `invalidValue` for the other two

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarSurvivesTheFile`, `aSidecarWithRulesSurvivesTheFile`, `rulesInsideAnItemAreNotTheContainers`, `anEmptySidecarIsMalformed`, `aRulesReferenceThatNamesNothingIsRefused`).

## ADDED Requirements

### Requirement: A presentation names the segments of the sources it was made from
A presentation's `sources` SHALL be the segments it was made from, in order, each written as one
`<source>` element: `scheme` and `value` when the segment's source has a natural key, and neither when
it has none; and `from` and `to`, the first and last chapters it spans counted from one, when the
segment is part of its source, and neither when it is the whole. Reading SHALL require `scheme` and
`value` together or neither, and `from` and `to` together or neither, as integers of at least 1 with
`from` no greater than `to`; a lone one SHALL throw `ContainerFileError.missingAttribute` for the
other, and a value outside those bounds `ContainerFileError.invalidValue`. The package SHALL NOT read a
key's scheme or value.

#### Scenario: a film across two discs, and an episode cut from a title
- **WHEN** a presentation made from two whole segments of sources with natural keys, and another made from chapter 2 of a source with no natural key, are written and read back
- **THEN** the first holds two `<source>` elements with their keys in order, the second one `<source from="2" to="2"/>`, and both read back equal

#### Scenario: a span that runs backwards
- **WHEN** a presentation's `<source>` has `from="3"` and `to="2"`
- **THEN** reading throws `invalidValue`

Pinned by: nothing yet.

### Requirement: A presentation names how it was made
A presentation's `madeBy`, when it has one, SHALL be written as one `<madeBy>` element with its
`ruleset` and `version`, holding, in order, one `<layer>` per rules layer — its `container`, its
`version` and, when set, its `digest` — and then one `<adjusted>` per adjusted stream, with its
`kind` and `index`. Reading SHALL require a non-empty `ruleset` and an integer `version` of at least 1
on `<madeBy>`; a `container` that is a valid container id and an integer `version` of at least 1 on
each `<layer>`; and a `kind` of `video`, `audio` or `subtitle` and an integer `index` of at least 1 on
each `<adjusted>`. A missing attribute SHALL throw `ContainerFileError.missingAttribute`, and any other
value outside those bounds `ContainerFileError.invalidValue`; more than one `<madeBy>` on a presentation
SHALL throw `ContainerFileError.invalidValue`. The package SHALL NOT read what a ruleset, a layer's
digest or an adjustment means.

#### Scenario: a presentation made through two layers, with one stream adjusted
- **WHEN** a presentation made by `household` version 7, through an episode container's rules at version 1 and a season's at version 4, with its first audio stream adjusted, is written and read back
- **THEN** it holds a `<madeBy ruleset="household" version="7">` with two `<layer>` elements nearest first and an `<adjusted kind="audio" index="1"/>`, and reads back equal

#### Scenario: an adjustment of something that is not a stream kind
- **WHEN** a presentation's `<adjusted>` has `kind="chapter"`
- **THEN** reading throws `invalidValue`

Pinned by: nothing yet.

### Requirement: The old source element reads as a disc title
Reading SHALL take a `<source>` with `disc` and `playlist` attributes as one whole segment of the
source whose natural key has the scheme `discTitle` and the value `<disc>/<playlist>`, and writing
SHALL write it in the form of the requirement above, so the old form is read and never written. A
`<source>` with `disc` or `playlist` and also `scheme` or `value` SHALL throw
`ContainerFileError.invalidValue`, since which identifies the source has no answer; one with only one
of `disc` and `playlist` SHALL throw `ContainerFileError.missingAttribute` for the other.

#### Scenario: a library written before provenance
- **WHEN** a sidecar whose presentation has `<source disc="3F1AC2E9" playlist="00004.mpls"/>` is read and written again
- **THEN** the presentation's one segment is the whole of the source keyed `discTitle` `3F1AC2E9/00004.mpls`, and the document written holds `<source scheme="discTitle" value="3F1AC2E9/00004.mpls"/>`

Pinned by: nothing yet.
