<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: A sidecar attributes fields and artwork, and declines references, as library facts
`Sidecar` SHALL carry `attributions`, each an `Attribution` of a `subject` to a `provider` and a
`value`, and `declined`, each an `ExternalRef`, both in the order listed. `SidecarFile.data(for:)`
SHALL write each attribution as an empty `<attribution subject provider value>` child of
`<container>`, and then each declined reference as an empty `<declined provider value>`, after the
container's own children and before its `<rules>`, which stays last. `SidecarFile.sidecar(from:)`
SHALL read them back, refusing one whose attribute is missing with
`ContainerFileError.missingAttribute` and one whose attribute is empty with
`ContainerFileError.invalidValue`. A subject SHALL be read as written: `Attribution.Subject` names
`outline`, an alternative's outline as `alternative/<id>/outline` and an artwork kind as
`artwork/<kind>`, and a subject that is none of these SHALL be read rather than refused, for
whoever checks the sidecar to report. The repository reader SHALL ignore both, an update SHALL
leave them as they stand, and so SHALL setting the container's own fields.

#### Scenario: an attributed outline and a declined reference
- **WHEN** a sidecar attributing its outline and its poster to provider `tmdb`, declining one `tmdb`
  reference and naming its rules is written and read
- **THEN** the sidecar read equals the one written, the `<declined>` element comes before the
  `<rules>` element, and the repository reader reads the sidecar's container

#### Scenario: kept through an update and an edit
- **WHEN** a sidecar with attributions and a declined reference is updated with a new presentation,
  and separately has its container's outline set
- **THEN** each result keeps the attributions and the declined reference as they were

#### Scenario: a subject nothing names
- **WHEN** a sidecar's `<attribution>` has the subject `tagline`
- **THEN** reading it yields an attribution whose subject is `tagline`, which names no field and no
  artwork kind

#### Scenario: an attribution with no value
- **WHEN** a sidecar's `<attribution>` has a subject and a provider and no `value`
- **THEN** reading throws `missingAttribute` naming `attribution` and `value`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`attributionsAndDeclinedRefsSurviveTheFile`,
`anUpdateAndAnEditKeepAttributionsAndDeclinedRefs`, `anAttributionsSubjectIsReadAsWritten`,
`anAttributionOrADeclinedRefMustSaySomething`).

### Requirement: Setting a sidecar's attributions or declined references changes only those
`SidecarFile.data(settingAttributions:in:)` SHALL read the document's container with
`ContainerFile.container(from:)`, so every refusal of that reader applies, and SHALL return the
document with its `<attribution>` children of `<container>` replaced by the given attributions, in
order, where the first of them stood; before the container's `<rules>` when it had none; or last when
it has no `<rules>` either. An empty list SHALL remove them. `SidecarFile.data(settingDeclined:in:)`
SHALL do the same for `<declined>`. Each SHALL change nothing else: comments, order, the container's
fields, presentations, child paths, rules and the other kind of fact stay as they are.

#### Scenario: attributions replaced
- **WHEN** a document with a comment, a presentation, one attribution before its sequence and a
  `<rules>` element has its attributions set to two others
- **THEN** reading the result yields the two attributions and everything else as before, the comment
  is still there, and the attributions stand before the sequence

#### Scenario: a declined reference added
- **WHEN** a document with a `<rules>` element and no declined references has one declined reference
  set
- **THEN** reading the result yields that reference, written before the `<rules>` element

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`settingAttributionsOrDeclinedRefsChangesOnlyThem`).
