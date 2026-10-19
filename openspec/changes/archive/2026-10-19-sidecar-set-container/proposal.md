<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Setting a sidecar's container

## Why
A console that edits a library's container writes its own fields into the sidecar, and must leave the
library's facts and the comments in the file as they are. An update does the reverse: it keeps the
container's own fields and changes only the facts. `SidecarFile` gains the counterpart, a setter for
the container's own fields, as the rules have setters of their own. Proposal: silo-server's
[Containers in the console](https://github.com/media-silo/silo-server/blob/main/Proposals/Containers.md),
step 2 ([media-silo/silo-server#83](https://github.com/media-silo/silo-server/pull/83)).

## What Changes
- `SidecarFile.data(settingContainer:in:)` makes a sidecar's own fields the value's, in the value's order, keeping each item's presentations and binding rules, each child's path and the container's rules, and the comments and unknown elements on what it does not change.
- An item the value no longer declares is removed with its facts, and a child's path is kept only for a child container the value still holds.
- A value for another container is refused with `ContainerFileError.idMismatch`.
