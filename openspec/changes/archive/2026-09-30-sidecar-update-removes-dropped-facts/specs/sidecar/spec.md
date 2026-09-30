<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: An update removes a library fact the value no longer has
An update SHALL remove the `<presentation>` elements of every item whose id is an item of the
value's sequences or extras and has no entry in `presentations`, and the `smd` attribute of every
child container item whose child the value's sequences or extras hold and has no path in
`children`. An item the document has and the value's container does not declare SHALL keep its
presentations and `smd` attribute, since it is drift left for a validator to report.

#### Scenario: a presentation removed from the value
- **WHEN** a document has presentations for `part1` and `part2`, and is updated with a sidecar whose container declares both parts and whose `presentations` has an entry for `part1` only
- **THEN** reading the result yields no presentation for `part2`

#### Scenario: a child path removed from the value
- **WHEN** a document has an `smd` path on a child the sidecar's container holds, and is updated with a sidecar whose `children` is empty
- **THEN** reading the result yields no path for that child

#### Scenario: an item only the document has
- **WHEN** a document has a presentation on an item the sidecar's container does not declare, and is updated
- **THEN** reading the result still yields that item's presentation

Pinned by: `Tests/SmdSidecarTests/SidecarFileTests.swift` (`anUpdateRemovesFactsTheValueNoLongerHas`).

## REMOVED Requirements

### Requirement: An update never removes a library fact the value no longer has
**Reason**: It recorded the defect in https://github.com/project-smd/SmdKit/issues/8, which this change fixes.
**Migration**: None; an update now brings the library's facts up to the value's, as documented.
