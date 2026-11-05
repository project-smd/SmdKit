<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright (c) 2026 the smddb project authors -->

## ADDED Requirements

### Requirement: A container may say when it premiered, who is in it and who made it
`Container` SHALL carry `premiered`, the date it was first broadcast or released, as a `CalendarDate`,
and `cast` and `crew`, each a list of `Participant`s in the order credited, the role a character for
the cast and a job for the crew. They SHALL be the container's own fields, as its title and outline
are, on a container of any type: an episode's air date and credits, a film's release date and credits,
a season's or a series' first broadcast. `CalendarDate` SHALL be a year, a month and a day that name a
day of the proleptic Gregorian calendar, made from and described as `yyyy-mm-dd`, and its initialiser
SHALL return nil for a string that is not one. `Participant` SHALL carry `externalRefs`, each an
`ExternalRef`, wherever it stands: in a container's cast or crew, or on a feature. A reference names
the person, as an entry's reference names the item.

#### Scenario: a calendar date
- **WHEN** `CalendarDate("2022-09-21")` and `CalendarDate("2022-02-30")` are evaluated
- **THEN** the first is a date whose description is `2022-09-21`, and the second is nil

#### Scenario: an episode's credits
- **WHEN** an episode container is made with a first date, a cast member playing a character and a
  director, each carrying a reference
- **THEN** the container carries the date, the cast member with the character and the director with
  the job, each with their reference

Pinned by: `Tests/SmdKitTests/SmdKitTests.swift` (`calendarDatesAreCheckedEverywhere`,
`aContainerCarriesItsCredits`).
