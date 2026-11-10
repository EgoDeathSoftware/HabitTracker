# Calendar history — November 10, 2026

T02 implemented: explicit empty periods, target replacement/activation/cancellation,
monotonic closure, calendar transitions, and earlier tracking extension.

Full Xcode simulator suite passed (15 Swift Testing tests, 1 UI launch test), using the
same command/device/toolchain recorded in `2026-11-10-domain-foundation.md`.
Evidence: `.build-evidence/t02-suite.log` and its referenced xcresult.

The first implementation run exposed timezone leakage in weekday calculation: interpreting
a UTC date with the system calendar shifted Mondays to Sundays. A focused regression reproduced
that error. Weekday calculation now explicitly uses UTC for date arithmetic. A separate test
prevented treating a backfill within the first partial week as a complete planned week.

Covered: exact midpoint and one second later, replacement/cancellation, missed-boundary
activation, January's 32-period empty gap, creation midnight/noon, leap day, end-exclusive
closure, Monday-to-Sunday transition, replacing pending calendar changes and moving targets,
rollback, backfill initial targets, and a normal DST-crossing week.

Interface ruling: calendar mutation methods throw validation errors rather than hiding date
arithmetic failures. Goal periods retain the initial inclusive calculation range and expose
`endDayExclusive` for storage/calendar boundaries. Snapshot values use mutable fields within
pure value transformations; no managed object enters the domain.

Remaining T02 verification: a transition's own midpoint needs a dedicated regression test.
No physical device checks have been performed. App Intents metadata warnings remain explained
as in the foundation evidence.
