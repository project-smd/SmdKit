<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# Unrepresentable invalid containers

Tracked by <https://github.com/project-smd/SmdKit/issues/7>. Spec deltas:
[`openspec/changes/unrepresentable-invalid-containers`](../openspec/changes/unrepresentable-invalid-containers).

## The defect

`ContainerFile.data(for:)` writes whatever `Container` it is given, and `LocalRepository.save`
passes every value through to it. The reader then refuses a set of those files, and because
`LocalRepository.containers()` reads every file, one unreadable file fails the whole listing. A
single bad save takes down every later read of the repository.

The values written that cannot be read back, measured against `main` at 6bfa50a:

| Value | Written as | Read as |
|---|---|---|
| An empty title | no `<title>` | `missingElement(container, title)` |
| A title of only whitespace | `<title>` of spaces | `""`, which the next save writes as no `<title>` |
| `Entry(id:type: .container)` with no `container` | no `container` attribute | `missingAttribute(item, container)` |
| Any other entry type with a `container` | the attribute | `invalidValue(item, container, …)` |
| `ContainerID(rawValue:)` not sixteen lowercase hex characters | the root `id`, and the file name | `invalidValue(container, id, …)`, or `unexpectedFile` from the repository |
| A ref naming an empty item, or an item containing `#` | the `ref` attribute | `invalidValue(item, ref, …)` |
| Any string holding a character XML 1.0 cannot carry (U+0001, say) | the character | `malformed`, the whole document |

The last row is not in the issue. It turned up while this proposal was being written, and it is the
same defect: a value the model accepts, in a file the reader refuses.

## Two ways out

The writer, or `save`, could check the value and throw. That puts a second copy of the reader's
rules on the write side, turns every write into a call that can fail on a value that should never
have existed, and protects only the path through the XML writer. JSON, the sidecar projection and
the ingestion editor would still carry the bad value until it reached a disk.

Or the model could make these values impossible to build, so the writer never meets one. That is
what this proposal does. The project is early enough for it to be cheap: the only code outside
SmdKit that constructs these types is the smd-tools ingestion app. The model then matches
`ContainerDatabase.md` in smddb, which already treats a child (`ChildContainerId` when the type is
`container`) and a ref (`RefEntryId`) as separate kinds of entry with their own fields.

## The shape

**`ContainerID` checks its shape in every initialiser.** `init?(rawValue:)` becomes failable and
does the check that `init?(_:)` does today, and `init?(_:)` remains as a spelling of it. `mint()`
builds its value without going through the check, since it cannot fail. Because `ContainerID` is
`RawRepresentable` and `Codable`, decoding a malformed id then throws `DecodingError.dataCorrupted`
without any code for it.

**`ItemID` is a new checked type for the ids of entries.** It accepts a non-empty string with no
`#`, no tab, line feed or carriage return, and no character XML 1.0 cannot carry. The `#` is
excluded because it separates the container from the item in a cross-container ref. Tab and the
line breaks are excluded because attribute normalisation turns them into spaces on read, so an id
holding one would come back as a different id. A ref's item is an `ItemID`, so an empty ref or a
ref with a `#` in its item cannot be built.

**`Title` is a new checked type for the container's title.** `Title.init?(_:)` trims whitespace and
newlines at both ends, the same set the reader trims, and returns nil when nothing is left or when
the text holds a character XML 1.0 cannot carry. `Title.init?(rawValue:)`, which decoding uses, accepts only text
that is already a title, so it refuses untrimmed text rather than altering it. `Container.title`
becomes a `Title`, so an empty or blank title cannot be built and a title reads back exactly as
written.

**`Entry` becomes an enum with one case per kind.**

```swift
public enum Entry: Hashable, Sendable {
    case leaf(Leaf)       // an episode, a film, a featurette: anything that holds nothing
    case child(Child)     // a child container
    case ref(EntryRef)    // an item declared elsewhere
}
```

`Entry.Leaf` carries an `ItemID`, an `EntryType`, `optional`, `title`, `outline` and external
references. `Entry.Child` carries the same, but with a `ContainerID` in place of the `EntryType`.
`EntryRef` is unchanged in shape, with an `ItemID` for its item. `Entry.id` stays as a computed
`ItemID?`, nil for a ref. `Entry.child(_:id:)` is replaced by `Entry.Child(id:container:)`.

A child is a case of its own, so `EntryType` must not be able to say `container`:
`EntryType.init?(rawValue:)` returns nil for `container`, the constant `EntryType.container` goes,
and an entry type is otherwise as open as it is now.

**The writer drops characters XML 1.0 cannot carry.** Every string that is not a checked type
(outlines, type labels, alternative and feature titles, provider values, participant names, the
ids of sequences, alternatives and features) is written with those characters removed, in one
place in the writer's helpers. A value holding one does not read back equal. That is recorded in
the round-trip requirement as the other drifts are (an empty outline reading as nil, a carriage
return as a line feed), and the file is always readable. Checking every one of those strings in
the model would put a checked type on each field in the package. Stripping costs one helper,
because the characters cannot be written at all, escaped or not.

With all of that in place, `ContainerFile.data(for:)` stays non-throwing and every document it
writes reads back.

## What the reader gains

The reader builds values through the same initialisers, so it now refuses the documents that
describe values the model cannot hold, and the rules exist in one place:

- an `<item>` whose `id` is not an `ItemID` throws `invalidValue(item, id, …)`;
- a `ref` whose item part is not an `ItemID` throws `invalidValue(item, ref, …)`, as an empty ref
  does today;
- a `<title>` that is blank once trimmed throws `invalidText(title, …)`.

A hand-written file with such an id or title stops reading. Nothing in the repository or its tests
writes one.

**Amended in implementation (#11).** `ContainerID` and `ItemID` each keep a single checked
initialiser, `init?(_:)`, and drop `RawRepresentable` for `LosslessStringConvertible`, with the
string in a `value` property. Two initialisers doing the same check made `ContainerID.init`
ambiguous as a function reference. Without `RawRepresentable`, each type writes its `Codable`
itself, decoding through the check and encoding as a bare string, as the conformance did. `Title`
keeps both its initialisers, because they differ: one trims, the other refuses untrimmed text.

## What it leaves alone

- **Cross-reference checks.** Unique item ids, an alternative naming a real sequence, a default
  naming a real alternative, an anchor naming a real item, a ref naming an item that exists. The
  reader does not check these either, so no file becomes unreadable over them. They belong to a
  container-level validator; smd-tools' `ContainerLibrary` does part of that today.
- **The optional text fields and the other local ids** stay `String`. The drifts listed above are
  all readable.
- **`Container.extrasAnchor`** stays `String?`. Any string reads back as written.
- **`Sidecar.presentations`** stays keyed by `String`. The sidecar writer already refuses a key
  that names no item.

## What the implementing pull request carries

- The model, the reader and the writer as above; `SmdSidecar` updated for the `Entry` cases.
- Tests pinning each requirement the deltas mark "nothing yet": one per row of the table, written
  as "cannot be built" for the model and "is refused" for the reader.
- The README's description of the model.
- `openspec archive unrepresentable-invalid-containers --yes`, with each `Pinned by:` filled in.

smd-tools follows once SmdKit has merged: the editor binds to the `Entry` cases, drafts hold a
`String` and build a `Title` or `ItemID` on save (turning `LibraryError.emptyTitle` into the
failure of that build), and the `Entry(id: "", type: .episode)` placeholder in `ContainerEditor`
goes.
