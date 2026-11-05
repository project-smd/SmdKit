<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# A container says when it premiered, who is in it and who made it

## Why
An episode is a programme of its own: it has a title, a date it was first broadcast, a cast and the
people who directed and wrote it, and a library's player should be able to show them. Held as a
container of type `episode`, as a film is held as a `movie`, those are the container's own fields,
facts that may go to smddb when they come from a CC0 source such as Wikidata. The model has a title
and an outline for a container, and participants for a feature, but no date and no credits, and a
participant has no way to say who the person is beyond a name. Proposal: silo-server's
[An episode is a container](https://github.com/media-silo/silo-server/blob/main/Proposals/EpisodeDetails.md),
step 1 ([media-silo/silo-server#166](https://github.com/media-silo/silo-server/pull/166)).

## What Changes
- `Container.premiered`, a `CalendarDate`, written as `<premiered>` after `<year>`, and refused on
  reading when it is not a calendar date.
- `Container.cast` and `Container.crew`, each a list of `Participant`s, written as `<cast>` and `<crew>`
  after the external references.
- `Participant.externalRefs`, written as `<externalRef>` children of `<participant>` wherever one
  stands, so the people in an episode's credits and those on a feature are matched by a provider's id
  rather than by name.
- A reader that predates them ignores the elements, as it ignores anything it does not know, so the
  container format's version does not change.
