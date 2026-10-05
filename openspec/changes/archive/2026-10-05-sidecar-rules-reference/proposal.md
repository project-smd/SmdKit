<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Rules by reference

## Why
A container's rules move out of the sidecar into a folder of numbered version files beside it, so a
library keeps every version a file was made by; the sidecar's `<rules>` element becomes an empty
reference naming the folder and the version in force. Proposal:
[Rules by reference](../../../Proposals/SidecarRulesReference.md).
Tracked by <https://github.com/project-smd/SmdKit/issues/21>.

## What Changes
- `<rules path="…" version="n"/>` replaces the inline element; a version is `<path>/<n>.xml`.
- `SidecarRules` holds `path` and `version`, with `file`; its canonical form goes.
- A `<rules>` element holding elements is refused as `inlineRules`.
