<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

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
