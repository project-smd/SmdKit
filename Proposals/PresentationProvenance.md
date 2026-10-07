<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Presentation provenance

Tracked by <https://github.com/project-smd/SmdKit/issues/24>. Spec deltas:
[`openspec/changes/presentation-provenance`](../openspec/changes/presentation-provenance).
The format is argued in smddb's [sources, bindings and provenance amendment](https://github.com/project-smd/smddb/pull/37);
this is its reading and writing here.

## The need

A presentation is a file a library made, and the sidecar is the library's record of it. Today the
record says which item the file is, which alternative and profile, which features its streams carry
and what its chapters are called — and, through one `<source disc playlist>` element, which disc
title it was ripped from. It says nothing of how the file was made, and its source names a single
disc title, whole.

A library's server that works out which presentations its current rules would make differently
needs both halves: what each was made from, and the rules that made it. media-silo's
[layered rulesets proposal](https://github.com/media-silo/silo-server/pull/47) does that. Kept only
in the server's state, the record is lost when a library is copied to another disk, restored from
backup or handed to another server — although, since [Rules by reference](SidecarRulesReference.md),
every version of every container's rules travels with the library.

smddb's amendment settles the format. A presentation names the **binding** it was made from — the
shared record of an entry's segments of sources — and keeps a copy of those segments so it describes
itself without the store; it names, in a **transform**, every set of rules that made it; and a
person's decision about one entry is not a separate list but the **binding's own rules**, a layer
nearest of all, named on the item. This proposal reads and writes all three.

## The shape

```xml
<item type="episode" id="part1">
    <rules binding="5b0e7c1a-…-91d2" path="rules/bindings/5b0e7c1a-…-91d2" activeVersion="2"/>
    <presentation profile="mobile" file="Part One - mobile.mkv">
        <source binding="5b0e7c1a-…-91d2">
            <segment scheme="discTitle" value="3F1AC2E9/00004.mpls" from="2" to="2"/>
        </source>
        <transform ruleset="household" version="7">
            <layer binding="5b0e7c1a-…-91d2" version="2" digest="sha256:77ab…"/>
            <layer container="00000000000000a3" version="4" digest="sha256:41d0…"/>
        </transform>
        <track feature="commentary1" audio="2"/>
        <chapter index="1" title="Opening"/>
    </presentation>
</item>
```

**Where it came from: `<source binding>`.** A presentation has at most one `<source>`, naming its
binding by id — a UUID, minted wherever the binding was first recorded — and holding one `<segment>`
per segment of the binding, in order, at least one. A segment names its source by natural key,
`scheme` and `value`, or by neither when the source has none, and, when it is part of its source, the
chapters it spans, `from` and `to`, inclusive, from one. In the model, `Presentation.source` becomes a
`PresentationSource` of `binding` and `segments`, each a `NaturalKey?` and a `ChapterSpan?`.
`SourceRef` goes, and with it `<source disc playlist>`.

**How it was made: `<transform>`.** A presentation has at most one `<transform>`, naming the ruleset
and its version and holding, nearest first, one `<layer>` per set of rules that took part: each names
what the rules belong to — a `binding`, by id, or a `container`, by its container id, exactly one of
the two — and their `version`, and may carry the `digest` of that version's file. `Presentation`
gains `transform: Transform?`, a `ruleset`, a `version` and `layers`, each a `Layer` whose `subject`
is a binding or a container.

**A binding's own rules: `<rules binding>` on an item.** An `<item>` may hold one `<rules>` per
binding with rules of its own, naming the binding, the folder of its versions and the version in
force, as the container's `<rules>` names the container's. `Sidecar` gains `bindingRules`, by item
id, each a `BindingRules` of a `binding` and its `SidecarRules`. Two for one binding on one item are
refused, as two on a container are, and so is one that holds rules: the rules are in their files.
Until now a `<rules>` inside an item was ignored as not the container's; it is still not the
container's, and it is now read as the binding's.

**`activeVersion`, not `version`.** A `<rules>` element's `path` names the folder of every version,
and the attribute that picks the one in force is `activeVersion`, on the container's `<rules>` as on
an item's, as smddb's [follow-up](https://github.com/project-smd/smddb/pull/38) names it, so that it
does not read like a `<layer>`'s `version`, which is the version that made a file. This renames the
attribute [Rules by reference](SidecarRulesReference.md) introduced: `SidecarRules.version` becomes
`activeVersion`, and `file` becomes `activeFile`, beside a `file(version:)` that finds any version's
file — which a reader needs to read the rules a `<layer>` names while another version is active.
Nothing has been released, so the old attribute is not read.

**This package checks structure and interprets nothing.** It requires what the format requires — a
binding id that is a UUID, a key's two attributes together or neither, a span's two together, from
one, running forwards, a layer of exactly one subject, versions from one, at most one `<source>` and
one `<transform>` — and leaves what a natural key, a ruleset, a layer or a rule means to the server
that wrote them.

**Writing, updating and setting.** A presentation's `<source>` and `<transform>` are written after its
attributes and before its tracks, and are part of the presentation, so an update that replaces a
presentation replaces them, as it does tracks. An item's binding `<rules>` are written before its
presentations. Like a container's, they are authored: an update leaves every item's binding
`<rules>` as it stands, and `SidecarFile.data(settingRules:binding:item:in:)` replaces, adds or
removes one and changes nothing else.

**The repository file never carries any of it**, as it carries no presentations and no rules.

## Choices

**The binding, plus a copy of its segments.** The binding id is the canonical answer to where a file
came from, and the one a correction sent upstream needs. An id alone means nothing to a reader
without the store, and a binding never contributed is in no store, so the segments are copied beside
it. They are the binding's content, not a second truth; a reader with the store compares them.

**The identity of the rules, not the rules.** The ruleset's versions are kept by its server and every
container's and binding's beside the sidecar, so a version and a digest are enough to find and check
exactly what made a file.

**A person's decision is a layer.** An adjusted stream recorded beside the layers would be a second
mechanism: a comparison would have to leave it out by hand, and making the file again would lose it.
As a rule in the binding's rules it is decided again the same way, and carried into the next file.

**On the item, not the presentation.** Every presentation made from a binding shares its rules, so
they are named once; a rule for one profile says so in the rules.

**No earlier form.** Nothing written with `<source disc playlist>` needs reading, so the package
reads and writes the one form.

## What changes for callers

- **silo-server** builds presentations at placement with `source: SourceRef?`. It moves to
  `PresentationSource` from the binding and its sources' natural keys, writes `transform` from the
  committed recipe, and reads binding rules for its stacks, as media-silo's layered rulesets steps
  describe. It tracks this package by branch and pins a revision, so it moves when it next updates
  the pin.
- **smd-tools** writes `<source disc playlist>` through `SourceRef` and moves to a binding with a
  `discTitle` segment.

## The implementing pull request

`PresentationSource`, `NaturalKey`, `ChapterSpan`, `Transform`, `Layer` and `BindingRules`;
`Presentation.source` and `transform`; `Sidecar.bindingRules`; reading, writing, updating and setting
them, and each refusal; `SourceRef` removed; `SidecarRules.activeVersion`, `activeFile` and
`file(version:)`, read and written as `activeVersion`; and the deltas archived. Tests: a presentation with two
segments, one a span and one with no key, and a transform of a binding layer and a container layer
survives the file; an item's binding rules survive the file and an update, and setting replaces, adds
and removes them and changes nothing else; each malformed part is refused — a binding that is not a
UUID, a `<source>` with no segment, a key or span half given, a span from zero or backwards, a layer
of no subject or of two, a version below one, two `<source>`s or `<transform>`s on a presentation,
two `<rules>` for one binding on an item, a binding `<rules>` holding rules; the repository file holds
none of it; `file(version:)` finds a version other than the active one.
