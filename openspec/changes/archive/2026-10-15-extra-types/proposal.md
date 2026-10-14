<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Extra types

## Why
A server that lets a rule tell a trailer from an interview, and a console that offers those types
beside a field, both need the types an extra is classified by spelled one way. smddb's structured
containers already spell them as Emby's `ExtraType`, and SmdKit named only `featurette` of the ten.
It now names the rest and lists them, while `EntryType` stays open. Proposal: silo-server's
[Extras](https://github.com/media-silo/silo-server/blob/main/Proposals/Extras.md), step 1.

## What Changes
- `EntryType` names `behindTheScenes`, `deletedScene`, `interview`, `trailer`, `scene`, `short`, `clip`, `themeSong` and `themeVideo` beside `episode`, `movie` and `featurette`.
- `EntryType.extraTypes` lists the ten types an extra is classified by, `featurette` first, in Emby's order.
