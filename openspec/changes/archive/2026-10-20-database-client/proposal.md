<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# The database as a client: a provisional id and a contribution

## Why
A console that creates a container smddb does not have needs an id for it, and one that proposes a
library's container back to smddb needs somewhere to offer it. smddb mints identity and takes
contributions through review, and there is no service yet to do either. `ContainerDatabase` gains
the two calls a service would answer, `provisionalID()` and `contribute(_:)`, and `LocalRepository`
answers them from the clone: it mints the id itself, and contributes by writing files the user
commits. A service can later implement the same calls, and a client written against them does not
change. Proposal: silo-server's
[smddb in the console](https://github.com/media-silo/silo-server/blob/main/Proposals/Smddb.md),
step 1 ([media-silo/silo-server#98](https://github.com/media-silo/silo-server/pull/98)).

## What Changes
- `ContainerDatabase.provisionalID()` answers an id for a new container, provisional until smddb accepts a container carrying it; `LocalRepository` mints one, minting again while a file is named for it.
- `ContainerDatabase.contribute(_:)` offers containers to smddb and answers a `Contribution`; `LocalRepository` writes each container's file as `save(_:)` does and answers `Contribution.written` with the files, in the order given, committing nothing.
- A contribution is refused whole, before anything is written, when two of its containers share an id, or when a container names a child, or refers to a container, that neither the database nor the contribution holds.
- `save(_:)` stays as it is: the clone's own writer, for a tool that edits the clone directly.
