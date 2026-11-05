<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# An item's details, in a file of its own named from its sidecar

## Why
A library's player has nothing to show on an episode's page: an entry carries its references and no
title, which is right for the repository, where a provider holds the title, and leaves the library with
nothing of its own to show. A library should be able to keep an item's title, outline, first air date,
cast and crew, in a file of the item's own beside its presentations, since they are the item's and not
its container's. Proposal: silo-server's
[An episode's details](https://github.com/media-silo/silo-server/blob/main/Proposals/EpisodeDetails.md),
step 1 ([media-silo/silo-server#166](https://github.com/media-silo/silo-server/pull/166)).

## What Changes
- `ItemDetails`: the `container` and `item` it describes, `title`, `outline`, `aired` as a calendar
  date, `cast` and `crew` as `Participant`s in the order credited, and `attributions`.
- `Participant.externalRefs`, written as `<externalRef>` children of `<participant>` wherever a
  participant is, so the people in an item's details and those on a container's features can be
  matched by a provider's id rather than by name.
- `ItemDetailsFile` reads and writes it as a document rooted at `<details container item>`.
- `Sidecar.details`, each leaf item's details file as a path, written as the `smd` attribute of the
  leaf's `<item>`. The repository reader ignores it; an update and setting the container's own fields
  leave it as it stands, and setting the container removes it with an item it no longer declares.
- `SidecarFile.data(settingDetails:item:in:)` sets or removes one item's path and changes nothing else.
