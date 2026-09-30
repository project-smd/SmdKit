<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Rules in the sidecar

## Why
A library's server keeps a container's encoding exceptions in its `.smd`, as a `<rules>` element,
so they travel with the library. Today that element survives an update only by accident, cannot be
read, and is lost by a read followed by a generate. `SmdSidecar` gains the element as a library
fact it carries without interpreting. Proposal:
[Rules in the sidecar](../../../Proposals/SidecarRules.md). Tracked by <https://github.com/project-smd/SmdKit/issues/16>.

## What Changes
- A new `SidecarRules` holds one `<rules>` element as XML, in one canonical form; `Sidecar` gains `rules`.
- Reading records the root `<container>`'s `<rules>` child, and refuses two as `multipleRules`.
- Generating writes `rules` as the last child of `<container>`.
- An update leaves the document's `<rules>` as it stands, whatever the value says.
- `SidecarFile.data(settingRules:in:)` replaces, adds or removes the element and changes nothing else.
- The container-file reader is recorded as ignoring `<rules>`, and the repository file as carrying none.
