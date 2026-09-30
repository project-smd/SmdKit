<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# One byte form on every platform

## Why
Both writers serialised through Foundation's `XMLDocument`, and Darwin and Linux write the same
document differently: Darwin declares `encoding="UTF-8"` and indents by four spaces, Linux declares
`encoding="utf-8" standalone="no"` and indents by two. A container saved unchanged on the other
platform differed on every line, and the sidecar's requirement that its declaration carry no
`standalone` was false on Linux, where CI runs. The writers now walk the tree themselves and write
Darwin's form everywhere. Proposal: the issue itself, which is small enough to carry the argument.
Tracked by <https://github.com/project-smd/SmdKit/issues/12>.

## What Changes
- `ContainerFile.data(for:)` writes one byte form on every platform: the declaration `<?xml version="1.0" encoding="UTF-8"?>`, one element per line indented by four spaces per level, text-only elements on one line, empty elements compact, and a final line feed.
- Both sidecar modes write the same form, so a document parsed from either platform's form is written back in this one; mixed content is written as it stands.
- An attribute value's tab, line feed and carriage return are written as character references, so a sidecar's presentation reads back with them.
- The reason the container writer folds line ends itself is restated: the file holds the value as it reads back, rather than the serialisers disagreeing.
