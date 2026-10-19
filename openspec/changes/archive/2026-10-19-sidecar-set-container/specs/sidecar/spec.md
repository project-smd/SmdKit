<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: Setting a sidecar's container changes only its own fields
`SidecarFile.data(settingContainer:in:)` SHALL return the document with the container's own fields —
every attribute and element `ContainerFile.data(for:)` writes for it — made the value's, so that
`ContainerFile.container(from:)` reads the result as exactly the value, for a container representable
in the document as the `container-file` spec's round-trip requirement defines it. Alternatives,
features, sequences, and the items of each sequence and of the extras SHALL stand in the value's
order. It SHALL keep the library's facts: every item whose id the value still declares, in any
sequence or the extras, SHALL keep its `<presentation>` elements and binding `<rules>` elements, and
the container's `<rules>` element SHALL be kept. An element the value does not change SHALL be kept
as it stands, its comments and mixed content included; a comment SHALL move with the element it
stands before, and every element that is not the container's own — a library fact, or one no reader
of this package knows — SHALL stay before the own element it stood before, or last in its parent when
no such element remains. A comment outside `<container>` SHALL be kept. The result SHALL be written in
the byte form every sidecar write produces, so setting a sidecar written from a value to that value's
container changes no byte.

#### Scenario: a container retitled, extended and reordered
- **WHEN** a sidecar document with a comment before `<container>`, a comment inside an item, presentations, a binding's rules on that item, a child's path and the container's rules has its container set to a value with a new title and year, one more alternative, one more feature and its first two items swapped
- **THEN** reading the result yields the value as its container, the same presentations, child paths, rules and binding rules as before, both comments still there with the item's comment still inside it, and the two items in the value's order

#### Scenario: the container the document already has
- **WHEN** a sidecar written from a value has its container set to that value's container
- **THEN** the bytes are unchanged

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`settingTheContainerChangesOnlyItsOwnFields`).

### Requirement: Setting a sidecar's container removes what it no longer declares
An item the document has and the value's sequences and extras do not declare SHALL be removed, with
its presentations, its binding rules and the comments before it: whoever sets the container decides
beforehand whether a library may lose them. A child's `smd` path SHALL be kept on the item that holds
the same child container in the value, and removed when the value holds that child nowhere. An item
the value declares and the document lacks SHALL be written as `ContainerFile` writes it, with no
library facts.

#### Scenario: an item with presentations, and a child, dropped
- **WHEN** a sidecar document with presentations on two items and a child's path has its container set to a value without one of those items, without the child and with a new item
- **THEN** reading the result yields the value as its container, the presentations of the item it kept and no others, and no child path

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`settingTheContainerRemovesAnItemItNoLongerDeclares`).

### Requirement: Setting a sidecar's container refuses another container's value
`SidecarFile.data(settingContainer:in:)` SHALL read the existing document with
`ContainerFile.container(from:expecting:)` expecting the value's id, and SHALL throw the reader's
error when the document is unreadable, and `ContainerFileError.idMismatch` when it describes a
different container.

#### Scenario: a value with another id
- **WHEN** a sidecar document has its container set to a value whose id is not the document's
- **THEN** the write throws `idMismatch`, naming the value's id and the document's

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`settingAnotherContainersValueIsRefused`).
