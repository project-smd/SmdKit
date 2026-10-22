<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# A sidecar attributes its outlines and artwork, and records what it declined

## Why
A console drafting a container from TMDb takes facts plainly, but an outline or an image is the
provider's contributors' work. A library has to keep whose it is, so that a player can credit it and
an export to smddb can leave it out. A provider's season 0 also lists things a library will not
hold, and the console needs that choice kept. Both are a library's facts, which the repository
document has no place for. Proposal: silo-server's
[TMDb in the console](https://github.com/media-silo/silo-server/blob/main/Proposals/Tmdb.md), step 1
([media-silo/silo-server#112](https://github.com/media-silo/silo-server/pull/112)).

## What Changes
- `Sidecar.attributions`, each an `Attribution` of a `subject` — `outline`, `alternative/<id>/outline` or `artwork/<kind>`, read as written — to a `provider` and a `value`, written as `<attribution>` children of `<container>`.
- `Sidecar.declined`, each an `ExternalRef`, written as `<declined>` children of `<container>`.
- Both are written before the container's `<rules>`, which stays last; the repository reader ignores them, an update and setting the container's own fields leave them as they stand.
- `SidecarFile.data(settingAttributions:in:)` and `data(settingDeclined:in:)` replace them and change nothing else.
