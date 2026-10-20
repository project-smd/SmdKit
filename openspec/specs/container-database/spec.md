<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Container database

## Purpose

`ContainerDatabase` is what a client asks of the database: every container, one by id, the ones a
provider's id names, and save, with the roots derived from those; and the two calls a service
would answer too, a provisional id for a new container and a contribution of containers offered to
smddb. `LocalRepository` is its one implementation, a folder that is a clone of the data repository
with one file per container under `containers/`, which mints the id itself and contributes by
writing files. This spec covers the interface's derived query and contribution check, and the
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

### Requirement: The local repository keeps one file per container, named for its id
`LocalRepository.save(_:)` SHALL create `<root>/containers/` when it is missing and write
`ContainerFile.data(for:)` to `containers/<id>.xml` atomically, creating the file or replacing the
one with that id. It SHALL NOT validate the container, commit, or touch anything else in the
folder; the folder need not be a git checkout. Every container the writer is given can be read
back (see the `container-file` spec), so a save SHALL NOT leave a file that makes a later
`containers()` fail.

#### Scenario: saving into an empty folder
- **WHEN** a container is saved to a repository whose root has no `containers` folder
- **THEN** the folder is created and holds a file named for the container's id with extension `xml`

#### Scenario: saving again
- **WHEN** a saved container's title is changed and it is saved again
- **THEN** reading it by id returns the new title

#### Scenario: a listing after saving text XML cannot carry
- **WHEN** a container whose outline holds U+0001 is saved and the repository's containers are listed
- **THEN** the listing succeeds and includes that container

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`, `aSaveNeverBreaksTheListing`).

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
SHALL return `nil` when no file is named for the id.

#### Scenario: no folder
- **WHEN** `containers()` is called on a repository whose root does not exist
- **THEN** it returns an empty list and does not throw

#### Scenario: an id with no file
- **WHEN** `container(_:)` is called for an id no file is named for
- **THEN** it returns `nil`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`).

### Requirement: Listing reads every xml file in name order and refuses a stray one
`containers()` SHALL read every file in `containers/` whose extension is `xml`, sorted by file
name, and SHALL ignore files with any other extension. A file whose name without extension is not a
valid container id SHALL make the call throw `LocalRepositoryError.unexpectedFile` naming it rather
than be skipped. Each file SHALL be read expecting the id its name carries, and a
`ContainerFileError` SHALL be rethrown as `LocalRepositoryError.unreadable` with the file's URL, so
one unreadable file fails the whole listing. Only `ContainerFileError`s are wrapped: a file-system
error, such as reading a directory named `<id>.xml`, SHALL propagate as the underlying error.

#### Scenario: a stray xml file
- **WHEN** a file `containers/notes.xml` is present and `containers()` is called
- **THEN** the call throws a `LocalRepositoryError`

#### Scenario: a file whose document names another id
- **WHEN** a file named for id A holds a container document with id B
- **THEN** reading it throws `unreadable` wrapping `idMismatch(file: A, document: B)`

#### Scenario: a zero-byte file
- **WHEN** a file named for a container id is empty and `containers()` is called
- **THEN** the call throws `unreadable` naming that file and wrapping `malformed`

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`, `aFileNamedForOneIdHoldingAnotherIsUnreadable`, `anEmptyFileIsMalformed`).

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
`ContainerID.mint()`, minting again for as long as `containers/` holds a file named for the id
minted, and SHALL write nothing. An id is provisional only in how it was issued: it is a
`ContainerID` like any other, and nothing about it records that it is provisional.

#### Scenario: an id for a new container
- **WHEN** `provisionalID()` is called on a repository holding containers
- **THEN** it answers an id that no file in the repository's containers folder is named for, and
  the folder is unchanged

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
