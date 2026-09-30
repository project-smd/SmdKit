<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: A sidecar is written as the repository file would be
Both modes SHALL write the byte form `ContainerFile.data(for:)` writes, on every platform, even
when the document was parsed from data with another declaration or indentation: the declaration
carries no `standalone` declaration, and whitespace-only text between elements is replaced by the
writer's indentation. An element holding text beside its elements is mixed content and SHALL be
written as it stands, with no whitespace added or removed inside it. An attribute value's tab, line
feed and carriage return SHALL be written as character references, so they read back unchanged.

#### Scenario: a generated document
- **WHEN** a sidecar with no presentations and no child paths is written from the value
- **THEN** the bytes equal those the repository writer writes for its container

#### Scenario: an updated document
- **WHEN** that sidecar is written as an update over its container's document, declared standalone and indented by two spaces
- **THEN** the declaration carries no `standalone` attribute, and the bytes equal those the repository writer writes for its container

#### Scenario: mixed content
- **WHEN** a sidecar is written as an update over a document whose outline holds text around an element
- **THEN** the outline is written as it stood

#### Scenario: whitespace in a presentation
- **WHEN** a presentation whose file name holds a tab, a line feed and a carriage return is written and read back
- **THEN** the file name read is the one written

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`aSidecarIsWrittenAsTheRepositoryFileWouldBe`, `anUpdateKeepsMixedContentAsItStands`, `aPresentationKeepsWhitespaceInItsAttributes`).
