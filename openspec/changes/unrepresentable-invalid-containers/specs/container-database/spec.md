<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

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

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`repositoryKeepsOneFilePerContainer`). The listing after saving text XML cannot carry is not yet measured.
