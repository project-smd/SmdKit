<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Presentation provenance

Tracked by <https://github.com/project-smd/SmdKit/issues/24>. Spec deltas:
[`openspec/changes/presentation-provenance`](../openspec/changes/presentation-provenance).

## The need

A presentation is a file a library made, and the sidecar is the library's record of it. Today the
record says which item the file is, which alternative and profile, which features its streams carry
and what its chapters are called — and, through one `<source disc playlist>` element, which disc
title it was ripped from. It says nothing of how the file was made from that source.

Both halves matter once a library's server works out which presentations its current rules would
make differently. media-silo's [layered rulesets proposal](https://github.com/media-silo/silo-server/pull/47)
compares, for each presentation, the rules it was made by against the rules that apply now, and says
whether its sources can be had to make it again. The server keeps that record in its own state. A
library copied to another disk, restored from backup or handed to another server keeps its files, its
sidecars and — since [Rules by reference](SidecarRulesReference.md) — every version of every
container's rules, but loses what made each file. The format's first principle is that the `.smd`
beside the files is the truth; provenance is part of that truth.

The source half has also outgrown its element. A presentation is made from segments of one or more
sources — a play-all title's second chapter, a film's two discs — and a source is identified by a
natural key with a scheme: a disc title, a content hash, an IMF composition's id. `<source disc
playlist>` names one disc title, whole. media-silo's [ingestion proposal](https://github.com/media-silo/silo-server/blob/main/Proposals/Ingestion.md)
left that as its first open question: the sidecar could record a natural key in the same shape, and
the server would derive it from the presentation's sources rather than carry it.

## The shape

A presentation gains two parts, both optional, between its attributes and its tracks:

```xml
<presentation profile="mobile" file="Part Three - mobile.mkv">
    <source scheme="discTitle" value="3F1AC2E9/00004.mpls" from="2" to="2"/>
    <madeBy ruleset="household" version="7">
        <layer container="00000000000000b7" version="1" digest="sha256:9f2c…"/>
        <layer container="00000000000000a3" version="4" digest="sha256:41d0…"/>
        <adjusted kind="audio" index="1"/>
    </madeBy>
    <track feature="commentary1" audio="2"/>
    <chapter index="1" title="Opening"/>
</presentation>
```

**Where it came from: one `<source>` per segment, in order.** Each names a source by its natural key,
`scheme` and `value`, and, when the segment is part of its source, the chapters it spans, `from` and
`to`, inclusive, counted from one. A film across two discs has two `<source>` elements; an episode cut
from a play-all title has one, with its span. A source with no natural key — a file that nothing
outside the server can identify — is recorded as a `<source>` with no `scheme` and `value`, so that
the segments keep their count, order and spans; a reader learns that the presentation was made from a
source it cannot name.

**How it was made: `<madeBy>`.** It names the ruleset and its version, `ruleset` and `version`, and
holds, nearest first, a `<layer>` for each container whose rules took part: the container's id, the
version of its rules, and the digest of that version's file, as its server took it. A container whose
rules did not take part — because it has none — has no `<layer>`. Then an `<adjusted>` for each stream
whose decision was changed by hand after the rules made it, by `kind` (`video`, `audio` or
`subtitle`) and `index` from one among streams of that kind, the way `<track>` counts.

**This package reads both and interprets neither.** It reads and writes the elements, checks that
each holds what the format requires — a `scheme` with its `value` or neither, positive chapter
numbers with `from` no greater than `to`, a container id that is an id, versions and indices from
one, a kind of the three — and leaves what a ruleset, a layer or an adjustment means to the server
that wrote them. The format names the parts of a derivation; the server decides what they are.

**In the model.** `Presentation.source: SourceRef?` becomes `sources: [PresentationSource]`, each a
`NaturalKey?` — `scheme` and `value` — and an optional `ChapterSpan`; `Presentation` gains
`madeBy: Derivation?`, a `ruleset`, a `version`, `layers: [RulesLayer]` — `container`, `version`,
`digest?` — and `adjusted: [AdjustedStream]` — `kind`, `index`. `SourceRef` goes.

**The old element reads as a disc title.** A `<source disc="…" playlist="…"/>` already in a library
reads as one whole segment of the source `discTitle:<disc>/<playlist>`, and is written back in the
new form when the presentation is next written. Libraries hold the old form today, written by the
servers and tools that place files, so refusing it would make them unreadable. A `<source>` with both
`disc` and `scheme` is refused, since which identifies the source has no answer.

**Placement writes it.** Both parts are a presentation's, and a presentation is replaced whole when a
placement writes it, so an update writes them as it writes tracks and chapters. Nothing else changes
them.

**The repository file never carries either**, as it carries no presentations.

## Choices

**The identity of the rules, not the rules.** `<madeBy>` names versions; it does not copy them. The
ruleset's versions are kept by its server, and every container's versions are in the library beside
its sidecar, so a version and a digest are enough to find, and check, exactly what made a file.

**Which streams were adjusted, not how.** An adjustment's action — copy this stream, encode that one
with these settings — is in the server's vocabulary, and the result is the file itself. What a later
comparison needs is to know which decisions were a person's rather than the rules', so that a change
of rules does not report them; `kind` and `index` say that.

**Not the facts.** The facts the rules were resolved against come from the sources' descriptions,
which the server holds and which a source registered again under the same natural key brings back.
Copying them into every presentation would make the sidecar a second home for them.

**One element per segment, not a list in an attribute.** The format writes one element per thing
everywhere else — a `<track>` per mapping, a `<chapter>` per name — and a segment has attributes of
its own.

**`scheme` and `value`, not one string.** A natural key's scheme decides how its value is read, and a
value may hold any character; two attributes need no escaping rule.

**Keeping the old form readable.** It is a second way to say one thing, which the format otherwise
avoids, but it is a way already on disk. It is read and never written, so it disappears from a library
as its presentations are placed again.

## smddb

The sidecar format is argued in smddb's `StructuredContainers.md`. Its description of `<presentation>`
gains the `<source scheme value from to>` elements, one per segment, in place of `<source disc
playlist>`, which it keeps as a form a reader accepts; and the `<madeBy>` element, with its `<layer>`
and `<adjusted>` children. That amendment lands in smddb alongside this change and the one
[Rules by reference](SidecarRulesReference.md) asks for.

## What changes for callers

- **silo-server** builds presentations at placement from a binding, with `source: SourceRef?`. It
  moves to `sources`, derived from the binding's segments and the natural keys of their sources, and
  writes `madeBy` from the committed recipe; its API's `SourceRef` follows. Until it does, it builds
  presentations with no `sources` and no `madeBy`.
- **smd-tools** writes `<source disc playlist>` through `SourceRef` and moves to a `discTitle`
  natural key.
- Both read sidecars already holding the old form without change.

## The implementing pull request

`PresentationSource`, `ChapterSpan`, `Derivation`, `RulesLayer` and `AdjustedStream`; `Presentation`'s
`sources` and `madeBy` in place of `source`; reading and writing both, the old form read as a disc
title, and each refusal; and the deltas archived. Tests: a presentation with two segments, one a span,
and a derivation of two layers and an adjustment survives the file; a source with no natural key keeps
its place; `<source disc playlist>` reads as one whole `discTitle` segment and is written in the new
form; each malformed part is refused — a `scheme` without a `value`, a span backwards or from zero, a
layer's container that is not an id, a version or index below one, a kind outside the three, and a
`<source>` with both forms; an update replaces a presentation's provenance with the value's; the
repository file holds none of it.
