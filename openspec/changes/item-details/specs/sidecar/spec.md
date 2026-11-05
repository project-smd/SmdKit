<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: An item's details are a document of their own
`ItemDetails` SHALL carry the `container` and `item` it describes, and optionally a `title`, an
`outline` and `aired`, the date the item first aired as `yyyy-mm-dd`, together with `cast` and `crew`,
each a list of `Participant`s in the order credited, and `attributions`, each an `Attribution` as a
sidecar's is. `ItemDetailsFile.data(for:)` SHALL write it as a `<details>` root with `container` and
`item` attributes, holding in this order `<title>`, `<outline>` and `<aired>` as text, each only when
set; `<cast>` and `<crew>`, each only when it has participants, holding one empty
`<participant name role>` per participant with `role` only when set, holding its external references as
the container file writes a participant's; and one empty
`<attribution subject provider value>` per attribution. `ItemDetailsFile.details(from:)` SHALL read it
back, refusing a document not rooted at `<details>` with `ItemDetailsFileError.notDetails`, a missing
`container` or `item` with `ContainerFileError.missingAttribute`, a `container` that is not a container
id, an `item` that is not an item id, and an `aired` that is not a calendar date, with
`ContainerFileError.invalidValue` or `invalidText`, and a participant with no `name` with
`missingAttribute`. A subject SHALL be read as written, as a sidecar's is.

#### Scenario: an episode's details survive the file
- **WHEN** details naming a container and an item, with a title, an outline, an air date, two of the
  cast, one with a role and a `tmdb` reference and one with neither, a director, and the outline attributed to provider `tmdb`, are
  written and read
- **THEN** the details read equal the details written, and the cast comes before the crew

#### Scenario: details with nothing in them
- **WHEN** details naming only their container and item are written
- **THEN** the document is a `<details>` element with its two attributes and no children

#### Scenario: an air date that is not a date
- **WHEN** a details document's `<aired>` is `2022-13-01`
- **THEN** reading it throws `invalidText` naming `aired`

Pinned by: `Tests/SmdSidecarTests/ItemDetailsFileTests.swift` (`anItemsDetailsSurviveTheFile`,
`detailsWithNothingInThemAreTheBareRoot`, `anAirDateThatIsNotADateIsRefused`).

### Requirement: A sidecar names each leaf item's details file
`Sidecar` SHALL carry `details`, each leaf item's details file as a path relative to the folder
holding the sidecar, by the item's id. `SidecarFile.data(for:)` SHALL write a leaf's path as the `smd`
attribute of its `<item>`, after its other attributes, and `SidecarFile.sidecar(from:)` SHALL read it
back. The repository reader SHALL ignore it, so the container read from a sidecar with details is the
container read from the same sidecar without them. Which file holds an item's details is authored, so
an update SHALL leave every leaf's `smd` as it stands, or its absence, whatever the value's `details`
say, and so SHALL setting the container's own fields for an item the value still declares. Setting the
container SHALL remove the path with an item it no longer declares, as it removes the item's
presentations.

#### Scenario: an episode's details named and read back
- **WHEN** a sidecar naming a details file for one of its episodes is written and read
- **THEN** the sidecar read equals the one written, the episode's `<item>` carries the path in `smd`,
  and the repository reader reads the sidecar's container

#### Scenario: kept through an update and an edit
- **WHEN** a sidecar naming an episode's details is updated with a new presentation for the episode,
  and separately has its container's title set
- **THEN** each result still names the episode's details

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anItemsDetailsAreNamedFromItsItem`,
`anUpdateAndAnEditKeepAnItemsDetails`).

### Requirement: Setting an item's details file changes only that
`SidecarFile.data(settingDetails:item:in:)` SHALL read the document's container with
`ContainerFile.container(from:)`, so every refusal of that reader applies, and SHALL return the
document with the `smd` attribute of the item's `<item>` set to the given path, or removed when the
path is nil. An item the container does not declare as a leaf SHALL throw
`SidecarFileError.unknownItem`. It SHALL change nothing else: comments, order, the container's fields,
presentations, child paths, rules, attributions and declined references stay as they are.

#### Scenario: details named on a hand-kept document
- **WHEN** a document with a comment and a presentation on an episode has the episode's details set to
  a path
- **THEN** reading the result yields the path for the episode, the same presentation, and the comment
  is still there

#### Scenario: a child container named as an item's details
- **WHEN** a document has details set for the item holding a child container
- **THEN** the write throws `unknownItem`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`settingAnItemsDetailsChangesOnlyThat`).
