<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Rules by reference

Tracked by <https://github.com/project-smd/SmdKit/issues/21>. Amends
[Rules in the sidecar](SidecarRules.md). Spec deltas:
[`openspec/changes/sidecar-rules-reference`](../openspec/changes/sidecar-rules-reference).

## The need

[Rules in the sidecar](SidecarRules.md) gave a library sidecar a `<rules>` element holding a
container's encoding rules inline, carried by this package without being read. Working out what the
library's server does with those rules showed that one inline copy is not enough.

media-silo's [layered rulesets proposal](https://github.com/media-silo/silo-server/pull/47) records
which rules made each file, and later works out which files the current rules would make
differently. With containers nested — a series, a season, an episode with commentaries of its own —
a file is made by a stack of them, and the server has to say which version of each container's rules
it used: the episode's rules at version 1, the season's at version 4, the series' at version 2. An
inline element has no versions. The server would have to keep its own copies of every version it
had used, under a digest, outside the library, which breaks the format's first principle in a new
way: the `.smd` beside the files is the truth, and a library copied to another disk, restored from
backup or handed to another server would keep its current rules but lose every version a file was
made by.

So a container's rules move out of the `.smd` into a folder of version files beside it, and the
`.smd` names the folder and the version in force.

## The shape

**A `<rules>` element names its rules and holds none.** A library sidecar's `<container>` may end in
one empty element:

```xml
<rules path="rules" version="4"/>
```

`path` is the folder, relative to the sidecar's own folder, as a child's `smd` path is. `version` is
the version in force, an integer from 1. A version is the file `<path>/<version>.xml` — here
`rules/4.xml` — holding the container's rules in the language of the server that applies them.

**`SidecarRules` is the reference.** `SidecarRules` holds `path` and `version`, and exposes `file`,
the version's path relative to the sidecar's folder, so that every reader finds a version in the
same place. The package reads neither the folder nor the files: the files' language is the server's,
as it was when the rules were inline, and which versions exist is the server's to know.

**Reading records it.** `SidecarFile.sidecar(from:)` sets `rules` from the `<rules>` child of the
root `<container>`, requiring a non-empty `path` and an integer `version` of at least 1. A `<rules>`
child holding elements — the inline form [Rules in the sidecar](SidecarRules.md) introduced — is
refused as `SidecarFileError.inlineRules`, rather than read for its attributes and its contents
dropped: a person who wrote rules inline would otherwise lose them without a word. A `<rules>`
anywhere else is not the container's and is ignored, and two `<rules>` children are refused, as
today.

**Writing, updating and setting are as today.** `SidecarFile.data(for:)` writes the reference as
the last child of `<container>`; an update leaves the document's `<rules>` as it stands, because a
placement knows nothing of rules; and `SidecarFile.data(settingRules:in:)` replaces, adds or removes
the reference and changes nothing else. A server changing a container's rules writes the new version
file first and then points the sidecar at it, as a placement writes a presentation's file before its
sidecar.

**The repository file never carries rules**, as today.

## Choices

**Naming the version in force, not the highest file.** The sidecar could name only the folder and
take the highest-numbered file as current. Naming the version keeps the `.smd` the truth about which
rules apply: a version file can be written and reviewed before the sidecar points at it, going back
to an earlier version is pointing at it again, and a change of rules is a change to the sidecar,
which every reader that watches sidecars already notices. The cost is two writes per change instead
of one.

**A path, not a fixed name.** `rules` will be the folder's name in practice, but a sidecar names
everything else it refers to — its children's sidecars, its presentations' files — by path, and a
reader should not have to know a convention to find a container's rules.

**Version files by number, not by digest.** A digest names a version exactly but says nothing about
order; a household asking whether a file was made by the season's current rules wants "version 4
of 6". A server that wants to notice a version file edited after it was used can record the file's
digest beside its number.

**Refusing the inline form.** Nothing has been released, and no reader of the inline form exists, so
accepting both forms would carry a second way to say the same thing into the first release for no
one's benefit.

**No canonical form.** The canonical spelling existed so that a server could digest the inline
element whatever its indentation. The rules are now whole files, which a server digests as bytes.

## smddb

The sidecar format is argued in smddb's `StructuredContainers.md`. The paragraph that
[Rules in the sidecar](SidecarRules.md) added changes to say that a library sidecar's `<container>`
may end in one empty `<rules>` element naming, by `path` and `version`, the folder of version files
beside the sidecar and the version in force; that a version is `<path>/<version>.xml`, in the
language of the library's server; and that a repository file holds none. That amendment lands in
smddb alongside this change.

## What changes for callers

- Nothing reads `Sidecar.rules` yet: silo-server's layered rulesets are proposed, not built. Its
  placement updates sidecars and so keeps a `<rules>` reference as it kept the inline element.
- smd-tools builds `Sidecar` values with `rules` defaulted to nil, and does not change.

## The implementing pull request

`SidecarRules` as `path` and `version` with `file`; reading, with the required attributes and the
refusal of the inline form; writing, updating and setting the reference; the canonical form removed;
and the deltas archived. Tests: a sidecar with a rules reference survives the file; `file` is
`<path>/<version>.xml`; a reference with no `path`, a `version` that is not an integer of at least 1,
or elements inside, is refused; an update keeps the reference, comment beside it included, whatever
the value says; setting replaces, adds and removes the reference and changes nothing else; two
`<rules>` children are still refused; a `<rules>` inside an item is still not the container's.
