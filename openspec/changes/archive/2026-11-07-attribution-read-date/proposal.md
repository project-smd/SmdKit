<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# An attribution says when its content was read

## Why
A provider's content, an outline or an image, is attributed where it is kept, and a provider's terms
may limit how long it can be kept: TMDb's forbid keeping anything read from it for more than six
months. A library can only warn before an attribution outlives such terms, and a console can only
offer to read it again, if the attribution says when its content was read. Proposal: silo-server's
[Facts from Wikidata, content from TMDb](https://github.com/media-silo/silo-server/blob/main/Proposals/Wikidata.md),
step 1.

## What Changes
- `Attribution.read`, a `CalendarDate`, the day the content was read from its provider, written as the
  `read` attribute of `<attribution>` after `value`.
- The attribute is required. An attribution without it is refused on reading with `missingAttribute`,
  as one without a value is, and one whose `read` is not a calendar date with `invalidValue`.
- No attribution written without a date is kept: the one library that holds attributions drafts them
  again, so nothing reads an attribution of unknown age.
