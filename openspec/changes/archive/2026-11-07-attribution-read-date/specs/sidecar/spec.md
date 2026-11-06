<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## MODIFIED Requirements

### Requirement: A sidecar attributes fields and artwork, and declines references, as library facts
`Sidecar` SHALL carry `attributions`, each an `Attribution` of a `subject` to a `provider` and a
`value`, read from that provider on the day `read`, and `declined`, each an `ExternalRef`, both in the
order listed. `SidecarFile.data(for:)` SHALL write each attribution as an empty
`<attribution subject provider value read>` child of `<container>`, `read` as `yyyy-mm-dd`, and then
each declined reference as an empty `<declined provider value>`, after the container's own children
and before its `<rules>`, which stays last. `SidecarFile.sidecar(from:)` SHALL read them back, refusing
one whose attribute is missing with `ContainerFileError.missingAttribute`, one whose attribute is empty
with `ContainerFileError.invalidValue`, and an attribution whose `read` is not a calendar date with
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

#### Scenario: the day an attribution was read
- **WHEN** a sidecar attributing its outline to `tmdb`, read on 5 November 2026, is written
- **THEN** its `<attribution>` carries `read="2026-11-05"` after its value, and reading it back yields
  that date

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

#### Scenario: an attribution with no date, or one that is not a date
- **WHEN** a sidecar's `<attribution>` has a subject, a provider and a value and no `read`, or a `read`
  of `2026-02-30`
- **THEN** reading throws `missingAttribute` naming `attribution` and `read`, or `invalidValue` naming
  `attribution`, `read` and `2026-02-30`

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`attributionsAndDeclinedRefsSurviveTheFile`,
`anUpdateAndAnEditKeepAttributionsAndDeclinedRefs`, `anAttributionsSubjectIsReadAsWritten`,
`anAttributionOrADeclinedRefMustSaySomething`).
