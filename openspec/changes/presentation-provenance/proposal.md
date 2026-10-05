<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Presentation provenance

## Why
A presentation records where it came from and how it was made: the segments of the sources it was
made from, each by natural key, and the ruleset, container rule versions and adjusted streams that
derived it, so that a library carries its own provenance wherever it goes. Proposal:
[Presentation provenance](../../../Proposals/PresentationProvenance.md).
Tracked by <https://github.com/project-smd/SmdKit/issues/24>.

## What Changes
- `<source scheme value from to>`, one per segment, replaces `<source disc playlist>`; the old form
  reads as a whole `discTitle` segment.
- `<madeBy ruleset version>` with `<layer container version digest>` and `<adjusted kind index>`.
- `Presentation.sources` and `madeBy` replace `source`; `SourceRef` goes.
