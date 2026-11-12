# Local data continuity

The focused migration and restore run passed three tests on the iOS 27.2 iPhone 18 Pro
simulator. Evidence is `.build-evidence/t10-restored-notices.log`. The existing V1-to-V2
migration fixture also ran and passed in this session.

The restore fixture copies the complete store directory while its writer is idle, including
committed WAL data. Reopening compares the complete StoreSnapshot, covering activity IDs,
nil completion timestamps, periods, pending target and calendar changes, reminders, and an
unacknowledged adjustment notice. Replaying the copied operation receipt returns wasReplay.
Reconciliation replaces a stale request with the exact planned queue from restored data.

An unreadable SQLite fixture fails to open and retains its original bytes. Missing model
discovery fails for a valid populated store, which then reopens normally with equal inventory.
Expected Core Data error diagnostics appear in the log for these deliberately failed opens.
No production reset or replacement-store recovery was added.

The app stores its database under Application Support and sets complete-until-first-user-
authentication file protection. Bundle model discovery is exercised by all on-disk tests.
Actual protected-data behavior, Apple backup restore, and Quick Start transfer remain
physical-device checks. The directory-copy test does not establish Apple backup/transfer
acceptance. No owner's device was reset or restored.
