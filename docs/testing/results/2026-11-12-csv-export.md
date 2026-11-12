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

Remaining checks include weekly uncapped observations and status precedence fixtures,
complete large-export responsiveness, and D5 interoperability with spreadsheet applications
on the owner's physical phone. No physical-device interoperability is claimed.
