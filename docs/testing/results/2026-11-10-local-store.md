# Transactional local store — November 10, 2026

T03 implemented with Core Data V1 and on-disk SQLite, one private writer context, error merge
policy, atomic rollback, named attributes/relationships, activity cascades, and durable retry
receipts. Local snapshots advance period history before reads. No-op reads preserve revision.

Full simulator suite passed: 21 domain/store tests and one UI launch test. The command and
simulator are as recorded in the foundation evidence. Local log: `.build-evidence/t03-suite.log`.

Actual tests cover independent concurrent logs, identical retry, conflicting payload reuse,
reopen then retry, retry after log deletion, full snapshot equality after reopen, unavailable
store path preserving an existing file, and an injected Core Data save validation failure.
The failed save preserved both the live snapshot and a separately reopened SQLite snapshot.
The remaining T02 transition-midpoint regression also passed.

Schema ruling from the model compiler: an entity with a uniqueness constraint cannot have
a mandatory inverse to-one relationship. Child-to-activity relationships are schema-optional;
commands and loaded mappings require a matching related activity/scalar UUID. Activity deletion
still cascades to its child rows. No orphan is accepted into a domain snapshot.

Apple references:
- https://developer.apple.com/documentation/coredata/using-core-data-in-the-background
- https://developer.apple.com/documentation/coredata/nspersistentcontainer/loadpersistentstores(completionhandler:)

V1 model is now the frozen tracking schema for later migration tests. A legacy data fixture
and actual V1→V2 migration tests remain for T10; migration is not claimed verified here.
The unavailable-path test verifies safe failure, not locked-device file-protection behavior.
Physical device backup, restart, and transfer checks remain pending.
