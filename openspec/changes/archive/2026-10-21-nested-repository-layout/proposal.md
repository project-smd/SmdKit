<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# The repository laid out as the tree of homes

## Why
A flat `containers/` folder of `<id>.xml` files cannot be navigated by hand, and while the data
repository is edited by hand that is where its people work. smddb's hosting proposal now lays the
containers out as the tree of their homes. Each container has a folder named for its position among
its parent's children, its title and its id, holding `container.xml` and its children's folders.
`LocalRepository` reads and writes that layout. The id stays the identity: a reader finds a
container by the id in its folder's name, never by its path. Proposal: smddb's
[Hosting](https://github.com/project-smd/smddb/blob/main/Proposals/Hosting.md), *The layout follows
the tree of homes* ([project-smd/smddb#40](https://github.com/project-smd/smddb/pull/40)).

## What Changes
- A container's folder is `<title> [<id>]` for one nothing holds, and `<NN> - <title> [<id>]` for one held as a child, numbered by its position among its parent's children and nested in its parent's folder. The title is written as a library writes a folder name.
- Every save puts every container where the layout says, moving folders, parents first, when a title, a home or a position has changed, so saving in any order converges on the same tree. A clone in the flat layout is converted by its first save, or by `settle()`.
- Listing walks the tree, reads each container folder's `container.xml` expecting the id its name carries, and lists in id order as before. A folder named for no id, or two folders for one id, fail the listing.
- `container(_:)` and `url(of:)` find a container's folder by its id wherever it is; `fileURL(for:)`, which built the flat path, goes.
- A provisional id is minted again while any folder in the tree is named for it.
- A save that would give a container a second home, or make it its own ancestor, is refused before anything moves. So is a contribution, through `checkContribution(_:)`, since one home per container is the model's rule and not this folder's.
