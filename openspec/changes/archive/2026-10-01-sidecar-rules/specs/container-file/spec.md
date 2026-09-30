<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: The reader ignores what it does not know
The reader SHALL ignore elements and attributes it does not read, including `<presentation>`
elements, `smd` attributes and a `<rules>` element, so a sidecar read with `ContainerFile` yields
its container unchanged. A document `ContainerFile.data(for:)` writes SHALL hold no `<rules>`
element, since a container has no rules: they are a library's fact, kept only in its sidecar. The
reader SHALL NOT check that local ids are unique or slugs, that an alternative's sequence exists,
that the default names an alternative, or that the extras anchor names an item.

#### Scenario: a sidecar read as a container
- **WHEN** a sidecar document with presentations and child `smd` paths is read with `ContainerFile.container(from:)`
- **THEN** the result equals the sidecar's container

#### Scenario: a sidecar with rules read as a container
- **WHEN** a sidecar document whose `<container>` ends in a `<rules>` element is read with `ContainerFile.container(from:)`
- **THEN** the result equals the sidecar's container

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`theRepositoryReaderReadsASidecarAsItsContainer`); a sidecar with rules is pinned by nothing yet.
