<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

# A sidecar update removes the facts the value dropped

## Why
`SidecarFile.data(for:updating:)` is documented as bringing the library's facts up to the value's,
but it only ever replaced or set them, so a presentation whose file had gone, or a child path
dropped from the value, survived in the document. Absence in the value now means removal, for the
items and children the value's container declares; an item only the document has is drift, and
keeps its facts for a validator to report. Proposal: the issue itself, which is small enough to
carry the argument. Tracked by <https://github.com/project-smd/SmdKit/issues/8>.

## What Changes
- An update removes the `<presentation>` elements of an item the value's container declares when `presentations` has no entry for it.
- An update removes the `smd` attribute of a child the value's container holds when `children` has no path for it.
- The requirement that an update never removes a library fact the value no longer has is removed.
