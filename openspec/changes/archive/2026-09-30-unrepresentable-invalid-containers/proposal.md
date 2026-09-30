<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Unrepresentable invalid containers

## Why
The container writer accepts values its own reader refuses, and one unreadable file fails every
later listing of the repository. Instead of a writer that checks and throws, the model makes those
values impossible to build, so every container the writer is given can be read back. Proposal:
[Unrepresentable invalid containers](../../../Proposals/UnrepresentableInvalidContainers.md).
Tracked by <https://github.com/project-smd/SmdKit/issues/7>.

## What Changes
- `ContainerID.init?(rawValue:)` checks the shape, so no unchecked id can be built or decoded.
- A new `ItemID` type holds entry ids and a ref's item: non-empty, with no `#`, tab or line break, and no character XML 1.0 cannot carry.
- A new `Title` type holds the container's title, trimmed and non-empty.
- `Entry` becomes an enum of `leaf`, `child` and `ref`, each case carrying only its own fields. `EntryType` can no longer be `container`.
- The writer drops characters XML 1.0 cannot carry from every other string, so every written document is well-formed.
- The reader refuses an item id or a ref that is not an `ItemID`, and a title that is blank once trimmed.
