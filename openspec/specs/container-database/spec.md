<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Container database

## Purpose

`ContainerDatabase` is what a client asks of the database: every container, one by id, the ones a
provider's id names, and save, with the roots derived from those; and the two calls a service
would answer too, a provisional id for a new container and a contribution of containers offered to
smddb. `LocalRepository` is its one implementation, a folder that is a clone of the data repository
with the containers under `containers/` laid out as the tree of their homes, a folder each named
for its position, title and id, which mints the id itself and contributes by writing files. This spec covers the interface's derived query and contribution check, and the
folder's behaviour. Discs, releases and bindings are not part of the interface yet.

Documentation: [README](../../../README.md) ("The repository layout").

## Requirements

### Requirement: Roots are the containers nothing holds
`ContainerDatabase.roots()` SHALL return every container whose id is not among the
`childContainerIDs` of any container in the database, in the order `containers()` returns them. A
ref SHALL NOT make the container it names held.

#### Scenario: a series, its season and a loose serial
- **WHEN** a database holds a series whose sequence holds a season as a child, the season, and a serial nothing holds
- **THEN** `roots()` returns the series and the serial, and not the season

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`).

### Requirement: Every read goes to disk
`LocalRepository` SHALL keep no cache: `containers()`, `container(_:)` and
`containers(matching:)` SHALL read the folder on every call, so an edit made outside the tool is
seen on the next read.

#### Scenario: a file edited outside the tool
- **WHEN** a container file is replaced on disk after it was read, and the same container is read again
- **THEN** the second read returns the file's new contents

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`everyReadGoesToDisk`).

### Requirement: A missing or empty folder is an empty database
`containers()` SHALL return an empty list when `containers/` does not exist, and `container(_:)`
SHALL return `nil` when no folder in the tree is named for the id.

#### Scenario: no folder
- **WHEN** `containers()` is called on a repository whose root does not exist
- **THEN** it returns an empty list and does not throw

#### Scenario: an id with no file
- **WHEN** `container(_:)` is called for an id no folder is named for
- **THEN** it returns `nil`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`).

### Requirement: Matching by external reference compares provider and value exactly
`containers(matching:)` SHALL return, in listing order, the containers whose own `externalRefs`
contain a reference equal to the one given, provider and value both. The external references of
items SHALL NOT be searched.

#### Scenario: a provider id that names a series
- **WHEN** a series carries the TVDB reference `76107`, no other container carries it, and `containers(matching:)` is called with that reference
- **THEN** it returns the series alone

#### Scenario: a provider id nothing carries
- **WHEN** `containers(matching:)` is called with a TVDB reference no container carries
- **THEN** it returns an empty list

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`, `matchingSearchesOnlyTheContainersOwnReferences`).

### Requirement: A provisional id is one the database holds no container for
`ContainerDatabase.provisionalID()` SHALL answer a `ContainerID` for a container nobody has yet,
provisional until smddb accepts a container carrying it. `LocalRepository` SHALL answer
`ContainerID.mint()`, minting again for as long as a folder anywhere in the tree under
`containers/` is named for the id minted, and SHALL write nothing. An id is provisional only in how
it was issued: it is a `ContainerID` like any other, and nothing about it records that it is
provisional.

#### Scenario: an id for a new container
- **WHEN** `provisionalID()` is called on a repository holding containers
- **THEN** it answers an id that no folder in the repository's tree is named for, and the tree is
  unchanged

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`aProvisionalIDIsOneTheRepositoryHasNoFileFor`).

### Requirement: A contribution names only containers the database or the contribution holds
`ContainerDatabase.contribute(_:)` SHALL refuse a contribution whole, writing nothing, when two of
its containers have the same id (`ContributionError.duplicate`), or when a container in it names,
as a child or as the container of a ref, a container that neither the database nor the
contribution holds (`ContributionError.missing`, naming the container and the id it names). Every
such container SHALL be named in the one error, not only the first found. A ref that names no
container refers within its own container and SHALL NOT be checked here.

#### Scenario: a series whose new season is not contributed
- **WHEN** a series whose seasons name a season the repository does not hold is contributed alone
- **THEN** the call throws `missing`, naming the series and the season, and no file is written

#### Scenario: the season contributed with it
- **WHEN** the same series is contributed together with the season
- **THEN** the contribution is accepted

#### Scenario: a ref to a container nobody holds
- **WHEN** a container whose extras refer to an item of a container the repository does not hold
  is contributed alone
- **THEN** the call throws `missing`, naming the referring container and the one referred to

#### Scenario: one id twice
- **WHEN** a contribution carries two containers with one id
- **THEN** the call throws `duplicate`, and no file is written

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`aContributionNamesOnlyContainersSomeoneHolds`).

### Requirement: The local repository contributes by writing each container's file, and commits nothing
`LocalRepository.contribute(_:)` SHALL write each container of an accepted contribution as
`save(_:)` writes it, in the order given, and SHALL answer `Contribution.written` with the URL of
each file it wrote, in that order. It SHALL NOT commit, or touch anything else in the folder:
what follows a contribution to the clone is the user's. A file-system error part way SHALL
propagate, leaving the files already written, each whole. `Contribution` SHALL declare only the
cases an implementation answers: a service's states are added with the service, so that a caller
switching on a contribution is made to decide what each new state means to it.

#### Scenario: a new container and a changed one
- **WHEN** a contribution carries a container the repository does not hold and a changed copy of
  one it does
- **THEN** the answer is `written` with both files, in the order given, the first is new, and
  reading the second by id returns the changed copy

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`aContributionToTheRepositoryWritesEachFile`).

### Requirement: The local repository lays its containers out as the tree of their homes
`LocalRepository` SHALL keep each container in a folder of its own holding its document,
`ContainerFile.data(for:)`, as `container.xml`. A container's home SHALL be the container whose
`childContainerIDs` include it. Its folder SHALL be inside its home's folder, or at the top of
`containers/` when no container in the repository holds it: one whose home is named but not held
stays at the top until its home is saved. A ref SHALL NOT make a home.

A folder's name SHALL be the container's title part followed by a space and its id in square
brackets, `<title> [<id>]`, for a container at the top. A container held as a child SHALL have its
position among its home's distinct children before that, counted from one in the order
`childContainerIDs` gives them, written in decimal, padded with zeros to two digits or to as many as
the home's count of children needs, and followed by ` - `: `03 - Pyramids of Mars [<id>]`. The title
part SHALL be the container's display title with `/` and `:` replaced by `-`, any NUL removed,
whitespace collapsed to single spaces, leading dots removed and the ends trimmed. When nothing
survives, the title part and the space after it SHALL be left out.

#### Scenario: a series with two seasons
- **WHEN** a series titled Doctor Who with year 1963 shown in its title, whose seasons sequence holds Season 12 and Season 13 in that order, is saved with both seasons
- **THEN** `containers/` holds the folder `Doctor Who (1963) [<series id>]` with `container.xml`, and inside it the folders `01 - Season 12 [<id>]` and `02 - Season 13 [<id>]`, each with its `container.xml`

#### Scenario: a title no filesystem takes
- **WHEN** a film titled `Alien: Covenant` is saved
- **THEN** its folder is `Alien- Covenant [<id>]`

#### Scenario: a parent with a hundred children
- **WHEN** a series holding 120 episodes as children is saved with them
- **THEN** the first episode's folder begins `001 - ` and the last's `120 - `

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`theRepositoryIsLaidOutAsTheTreeOfHomes`).

### Requirement: Every save puts every container where the layout says
After `save(_:)` returns, every container in the repository SHALL be in the folder the layout gives
it, and the saved container's `container.xml` SHALL hold the value. A container whose folder is not
the one the layout gives it SHALL be moved there with everything its folder holds, homes before
their children, so that a retitled container's folder is renamed, a container given a new home is
moved beneath it, and the siblings after a child inserted or reordered are renumbered. The order in
which containers are saved SHALL NOT change the tree they end in. A container kept as a flat
`containers/<id>.xml` file, as the layout before this one kept them, SHALL be read as a container
out of place and moved into a folder of its own as `container.xml` by the next save.
`LocalRepository.settle()` SHALL do the same with nothing saved, and SHALL move nothing when
everything is in place. The repository SHALL NOT commit, or touch anything outside `containers/`.

#### Scenario: a season saved before its series
- **WHEN** a season is saved, and then the series that holds it
- **THEN** the season's folder is inside the series' folder, numbered by its position

#### Scenario: a retitled series
- **WHEN** a saved series with a saved season is saved again with a corrected title
- **THEN** the series' folder carries the new title, and the season's folder and file are inside it, unchanged

#### Scenario: a season inserted first
- **WHEN** a series holding Season 13 is saved again with Season 12 inserted before it, and Season 12 saved
- **THEN** Season 12's folder begins `01 - ` and Season 13's folder, renamed, begins `02 - `

#### Scenario: a clone in the flat layout
- **WHEN** a repository holds a series and its season as `containers/<id>.xml` files and `settle()` is called
- **THEN** each is moved into its folder in the tree as `container.xml`, and no `<id>.xml` file is left

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`aSaveSettlesTheLayout`).

### Requirement: Listing reads every container folder in the tree, in id order
`containers()` SHALL walk the tree under `containers/` and read the `container.xml` of every folder
whose name ends in a container id in square brackets, expecting that id, and SHALL also read any
flat `<id>.xml` file at the top of `containers/`. It SHALL return the containers sorted by id, as
the flat layout's listing in file-name order did. A folder whose name ends in no container id, a
container folder with no `container.xml`, and two folders or files for one id SHALL make the call
throw `LocalRepositoryError.unexpectedFile` naming the folder or file rather than be skipped. Files
other than `container.xml` inside a container's folder, and files at the top that are not `xml`,
SHALL be ignored. A `ContainerFileError` SHALL be rethrown as `LocalRepositoryError.unreadable`
with the file's URL, so one unreadable file fails the whole listing; a file-system error SHALL
propagate as itself. A folder's position and title SHALL NOT be checked by the reader: whether
each folder is where the layout says is the validator's to report, and the next save's to fix.

#### Scenario: a stray folder
- **WHEN** a folder `containers/notes` is present and `containers()` is called
- **THEN** the call throws `unexpectedFile` naming it

#### Scenario: a document that names another id
- **WHEN** the folder for id A holds a `container.xml` whose container has id B
- **THEN** reading it throws `unreadable` wrapping `idMismatch(file: A, document: B)`

#### Scenario: a zero-byte file
- **WHEN** a container folder's `container.xml` is empty and `containers()` is called
- **THEN** the call throws `unreadable` naming that file and wrapping `malformed`

#### Scenario: one id in two folders
- **WHEN** two folders in the tree are named for the same id
- **THEN** `containers()` throws `unexpectedFile` naming the second

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`, `aFileNamedForOneIdHoldingAnotherIsUnreadable`, `anEmptyFileIsMalformed`, `aContainerIsFoundByItsIdWhereverItIs`).

### Requirement: A container is found by its id, wherever its folder is
`container(_:)` SHALL return the container whose folder anywhere in the tree is named for the id,
and `LocalRepository.url(of:)` SHALL return the URL of its `container.xml`, or `nil` for an id no
folder is named for. Neither SHALL depend on the container's title, position or home.

#### Scenario: a serial three levels down
- **WHEN** a serial is saved inside a season inside a series, and `container(_:)` is called with the serial's id
- **THEN** it returns the serial, and `url(of:)` names the `container.xml` in its folder

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`aContainerIsFoundByItsIdWhereverItIs`).

### Requirement: No container has two homes
`StructuredContainers.md` gives every item one home, and a child container is an item of its home.
`LocalRepository.save(_:)` SHALL throw `LocalRepositoryError.twoHomes`, naming the child and both
containers, when the value names as a child a container another container in the repository
already holds, and `LocalRepositoryError.cycle` when the value would hold one of its own ancestors;
either SHALL be thrown before anything is written or moved. `ContainerDatabase.checkContribution(_:)`
SHALL refuse a contribution whole with `ContributionError.twoHomes` when, the contribution's
containers taking the place of the database's with the same ids, a container would be held by two,
naming every such child and its homes.

#### Scenario: a season saved into a second series
- **WHEN** a season is held by one saved series, and a second series naming it as a child is saved
- **THEN** the save throws `twoHomes` naming the season and both series, and nothing is written

#### Scenario: a season moved in one contribution
- **WHEN** a contribution carries a series that no longer names a season and another series that now does
- **THEN** the contribution is accepted, and the season's folder moves beneath the second series

#### Scenario: a container holding its own parent
- **WHEN** a saved season held by a series is saved naming the series as its child
- **THEN** the save throws `cycle`, and nothing is written

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`noContainerHasTwoHomes`).
