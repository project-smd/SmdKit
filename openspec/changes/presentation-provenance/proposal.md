<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Presentation provenance

## Why
A presentation records where it came from and how it was made: the binding it was made from, with a
copy of the binding's segments of sources, and a transform naming every set of rules that made it.
A person's decision about one entry is the binding's own rules, named on the item. smddb's amendment
argues the format. Proposal: [Presentation provenance](../../../Proposals/PresentationProvenance.md).
Tracked by <https://github.com/project-smd/SmdKit/issues/24>.

## What Changes
- `<source binding>` with one `<segment scheme value from to>` per segment replaces
  `<source disc playlist>`; `SourceRef` goes.
- `<transform ruleset version>` with a `<layer binding|container version digest>` per set of rules.
- A `<rules>` element's version in force is `activeVersion`, container and binding alike;
  `SidecarRules` gains `activeFile` and `file(version:)`.
- An item's `<rules binding path activeVersion>`, one per binding with rules of its own, read, kept by an
  update and set on its own.
