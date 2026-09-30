<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Rules in the sidecar

Tracked by <https://github.com/project-smd/SmdKit/issues/16>. Spec deltas:
[`openspec/changes/sidecar-rules`](../openspec/changes/sidecar-rules).

## The need

A library's server decides how each ripped file is encoded from a ruleset, and a household's
exceptions belong to containers: this serial's restored extras are kept whole, that season's
isolated scores are never touched. media-silo's
[layered rulesets proposal](https://github.com/media-silo/silo-server/blob/propose-layered-rulesets/Proposals/LayeredRulesets.md)
puts those exceptions where the container is, in its `.smd`, as a `<rules>` element whose rules are
tried ahead of the library's. The reason is the format's own first principle: the `.smd` beside the
files is the truth, so a library copied to another disk, restored from backup or handed to another
server keeps what each container asked for.

That makes `<rules>` a library fact, like `<presentation>` and the `smd` path: something a library
keeps about a container that the data repository does not. And a library fact is this package's to
read and write, in `SmdSidecar`, because a sidecar has one reader.

## What happens today

Measured against `main` at 3fc5934, with a sidecar whose `<container>` ends in a hand-written
`<rules>` element holding a comment and one rule:

| Operation | Result |
|---|---|
| `ContainerFile.container(from:)` | reads the container unchanged; `<rules>` is ignored |
| `SidecarFile.sidecar(from:)` | reads the sidecar; `<rules>` is ignored, and the value has nowhere to hold it |
| `SidecarFile.data(for:updating:)` with a new presentation | keeps `<rules>`, comment included, re-indented as the writer indents |
| `SidecarFile.data(for:)` on the value just read | writes no `<rules>` |
| a document with two `<rules>` elements | reads without complaint |

So the element survives an update, which is how a library places a file into a container that
already has a sidecar — but by accident. No requirement says an update keeps an element it does not
read, and no test would notice if it stopped. Nothing can read the rules, so the server would need
a second reader of the `.smd` to find them. And a caller that reads a sidecar and writes it back
from the value loses them without a word.

## The shape

**`Sidecar.rules` holds the element, uninterpreted.** A new `SidecarRules` value holds one
`<rules>` element as XML, and `Sidecar` gains `rules: SidecarRules?`. This package does not read
the rules inside: their language — the facts, operators and actions a rule may use — is defined by
the server that applies them, in media-silo's
[rulesets spec](https://github.com/media-silo/silo-server/blob/spec-rulesets/openspec/specs/rulesets/spec.md),
and a copy of it here would be a second definition to keep in step. The format defines the slot;
the library's server defines what goes in it. `SidecarRules` checks only what the slot needs: the
text is well-formed XML with one root element named `rules`.

**One canonical form.** `SidecarRules` holds the element as `XMLWriter` writes it at the top level
— four-space indentation counted from the element itself, comments kept, whitespace-only text
between elements dropped, mixed content as it stands — with no declaration. The value is built from
any spelling and holds the canonical one, so two spellings of the same element compare equal, a
sidecar with rules reads back equal to the one written, and a server that records which rules made
a file can hash `SidecarRules.xml` and get the same digest whatever the indentation on disk.

**Reading records it.** `SidecarFile.sidecar(from:)` sets `rules` from the `<rules>` child of the
root `<container>`, when there is one. A `<rules>` anywhere else — inside an item, say — is not the
container's and is ignored, as any element the reader does not read is. Two `<rules>` children of
the root are refused as `SidecarFileError.multipleRules`, because which one the server should apply
has no answer.

**Generating writes it.** `SidecarFile.data(for:)` writes the value's `rules`, when set, as the last
child of `<container>`, after the extras.

**An update leaves it alone.** `SidecarFile.data(for:updating:)` leaves the document's `<rules>` as
it stands, whatever the value's `rules` says. This is the rule an update already follows for the
container's own fields, and for the same reason: the caller of an update is a placement, which
computes every presentation and child path it writes but knows nothing of the rules a person wrote.
The alternative — an update replacing the document's rules with the value's, as it does
presentations — would erase a container's rules every time a placement built its value without
reading them, which is exactly the loss the table above measured for generation. So rules are
authored facts, not derived ones: an update keeps them.

**Changing them is its own call.** `SidecarFile.data(settingRules:in:)` takes the rules, or nil, and
a document on disk, and returns the document with its `<rules>` replaced, added as the last child of
`<container>`, or removed. It reads the container first, so every refusal of the reader applies,
and changes nothing else: comments, order and every other fact stay, and the document is written in
the form every sidecar write produces. A console or route that edits a container's rules calls it;
nothing that places a file does.

**The repository file never carries rules.** `ContainerFile` has no `rules` to write, so a
repository document holds none; its reader goes on ignoring a `<rules>` element in a sidecar it is
given. The container-file spec says so, as it already says of presentations and `smd` paths.

## Choices

**No namespace.** The element could be `<silo:rules xmlns:silo="…">`, marking its contents as
another project's vocabulary. The format uses no namespaces anywhere, a person edits this element by
hand in the same file as the rest, and the slot is the format's own: what is foreign is the contents,
and they are opaque here whichever way the element is spelt.

**No format attribute from this package.** The rules' language will change, and the server needs
to tell one version of it from another. That is the language's concern; whatever attributes the
server's language puts on `<rules>`, `SidecarRules` keeps as written.

**Opaque rather than modelled.** Modelling the rules as types here would put a media server's
encoding vocabulary into the container model, and would make every change to that vocabulary a
release of this package. Held as XML, the element is carried faithfully by a package that neither
understands nor needs to.

## smddb

The sidecar format is argued in smddb's `StructuredContainers.md`, and this adds an element to it. The
format document gains a paragraph saying that a library sidecar's `<container>` may end in one
`<rules>` element, holding encoding rules the library's server applies to what the container holds,
in that server's language, and that a repository file holds none. That amendment lands in smddb
alongside this change.

## What changes for callers

- smd-tools' ingestion app and silo-server's placement build `Sidecar` values; the new parameter
  defaults to nil, so neither changes.
- silo-server's placement updates a sidecar that exists and generates only one that does not, so it
  keeps every container's rules without change. Its index and walker read sidecars with
  `SidecarFile.sidecar(from:)`, and gain the rules through `Sidecar.rules` instead of reading the XML
  a second way.

## The implementing pull request

`SidecarRules`, with its canonical form written by `XMLWriter`; `Sidecar.rules`; reading,
generating, the refusal of two, and `data(settingRules:in:)`; and the deltas archived. Tests: two
spellings of one element compare equal and hold the same `xml`; a sidecar with rules survives the
file; the repository reader still reads it as its container; an update over a document with rules
keeps them, comment included, whatever the value says; setting replaces, adds and removes, and
changes nothing else; two `<rules>` children are refused; a `<rules>` inside an item is not the
container's.
