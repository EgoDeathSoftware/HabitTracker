# CSV export progress

The app exposes inclusive date selection under Settings, streams UTF-8 daily summaries,
and shares through UIActivityViewController. It holds its temporary file through sharing
and removes it on dismissal. Startup cleanup removes interrupted HabitTracker CSV files
from the dedicated temporary export directory. Cleanup failure does not block store opening.

Five focused export tests and one UI test passed on the iOS 27.2 iPhone 18 Pro simulator.
Evidence is `.build-evidence/t09-flow.log`. Coverage includes the exact header, zero dates,
capped daily credit, historical daily target changes, travel preserving assigned dates,
date-only completions, invalid/future/empty ranges, cancellation before and during writing,
interrupted-file cleanup, formula prefixes, Unicode, commas, quotes, and CRLF.
The cancellation fixture contains 10,001 daily periods. It observes a temporary file before
cancelling and verifies no partial file remains. The UI test opens and dismisses system
sharing and verifies the saved completion count afterward.

Explicit CRLF examples exposed a Swift grapheme-cluster bug in the first escaping check.
The exporter now checks Unicode scalar character membership and quotes CRLF correctly.
The first UI run needed a wait for the share dismissal/navigation animation to finish.

Seven export tests passed in `.build-evidence/t09-final.log`, adding uncapped weekly
active-day observations and initial-partial/transitional status precedence. The full ten-year,
25-habit fixture produced 91,325 data rows. Initial export time was 22.83 seconds. Advancing
through sorted periods instead of searching them for every row reduced export time to
2.07 seconds in `.build-evidence/t10-continuity.log`. Timing excludes fixture construction.
The exporter runs on the concurrent executor and checks cancellation on every row.

D5 interoperability with spreadsheet applications on the owner's physical phone remains
unverified. No physical-device interoperability is claimed.
