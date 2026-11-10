# Local storage and domain design

Date: 2026-11-10.
Status: Recommended design, ready for owner review before development.
Authority: [Accepted product specification](../../SPEC.md). This document proposes internal
implementation choices; it does not change the accepted product behavior.

## Decision

Use **Core Data with one local SQLite persistent store**, native SwiftUI, and no third-party
dependencies. Use `NSPersistentContainer`, never `NSPersistentCloudKitContainer`. Keep the
database in the app's Application Support directory and eligible for ordinary Apple backups.
Do not add CloudKit, iCloud documents, accounts, remote services, or synchronization entitlements.

| Candidate | Fit | Decision |
| --- | --- | --- |
| Core Data / SQLite | Explicit save/rollback, uniqueness constraints, versioned models, native migration tooling. Requires mapping managed objects to Swift values. | Recommended for the transactional history and correction rules. |
| SwiftData | Native, concise, supports local configuration and versioned migration. Would also satisfy the local-only requirement. | Viable alternative; Core Data's explicit context/transaction control is preferred here. |
| Direct SQLite | Full SQL and transaction control. Requires maintaining schema migration, bindings, and row mapping ourselves or adding a wrapper. | Additional work without a product benefit for this app. |

This is an engineering preference, not a claim that SwiftData is unreliable. Apple documents
[Core Data queue confinement](https://developer.apple.com/documentation/coredata/using-core-data-in-the-background)
and [lightweight migrations](https://developer.apple.com/documentation/coredata/migrating-your-data-model-automatically).
SwiftData also supports [migration plans](https://developer.apple.com/documentation/swiftdata/modelcontainer)
and [explicitly disabling CloudKit](https://developer.apple.com/documentation/swiftdata/modelconfiguration/cloudkitdatabase-swift.struct/none).

## Runtime boundaries

- One app target owns the store. Put the App Intent in that target, with foreground execution
  as the initial supported mode. No separate extension, widget, or App Group is needed for v1.
- One `HabitStore` actor owns one long-lived private-queue context. Every read or mutation uses
  that context's `perform` operation; managed objects never leave its queue. Return immutable
  `Sendable` Swift values. Do not use a new independent writer context for each invocation.
- Each command performs its complete read/validate/mutate/save in one context operation with
  no suspension inside the transaction. On any failure, roll back the context and throw.
  Use the error merge policy; never silently overwrite conflicting rows.
- Views and the App Intent call the same `ActivityActions` service. It captures the clock once,
  creates an operation ID once for each logging invocation, and retains both for retries.
  Confirmation and navigation only render the saved result; they never call logging again.
- Goal rules, period rules, report calculations, reminder learning, and CSV row generation are
  pure functions over snapshots. Persistence and system notification delivery are separate.
- Increment the store revision only for committed changes. A no-op refresh or read must not
  advance the revision or create notices; otherwise reconciliation could loop indefinitely.
- A database commit precedes notification reconciliation. A notification error is a separate
  recoverable scheduling state and cannot change a successful logging result into a failed log.
- Use Swift Testing for domain/store tests and XCTest/XCUITest for UI interaction. Simulator
  tests supplement the physical-device checks in the [acceptance matrix](../testing/acceptance-matrix.md).

## Persisted model

All identifiers are UUIDs. Dates below mean a Gregorian `CalendarDay`, stored as a canonical
`YYYY-MM-DD` string; they are not UTC-midnight timestamps. Instants use Core Data Date values.
Enums use stable string values. Store named attributes and relationships, not opaque serialized
copies of the whole model. Define inverse relationships and explicit cascade/nullify rules.
Where an index or compound constraint uses `activityID`, persist that scalar UUID alongside
the Activity relationship and set both in the same transaction. Core Data constraints use
attributes; the scalar ID must always match the related Activity's ID.

| Entity | Fields and constraints | Purpose |
| --- | --- | --- |
| `Activity` | Unique `id`; `name`, `symbolName`, `cadence`, `createdAt`, `createdDay`, `trackingStartDay`, `trackingStartsAtMidnight`, immutable `initialTarget`, `effectiveTarget`; optional `pendingTarget`, `pendingTargetStartDay`. | Stable identity and plan state. Names may duplicate. Cadence cannot change. |
| `Completion` | Unique `id`; required Activity; `assignedDay`, optional `occurredAt`, `captureTimeZoneID`, `createdAt`, `source`, unique `operationID`, `wasTimeOrDateEdited`. | Raw observations. Counts are derived from these rows, never incremented counters. |
| `OperationReceipt` | Unique `operationID`; required Activity; `completionID`, original `assignedDay`, optional original `occurredAt`, `captureTimeZoneID`, `source`. | Stores the accepted logging request even if its completion is later corrected/deleted. Retain for the activity's lifetime. |
| `GoalPeriod` | Unique `(activityID, startDay)`; required Activity; `startDay`, `endDayExclusive`, `target`, `targetAppliedAt`, `eligibility`, optional `closedAt`, optional calendar-rule relation. | Explicit targets and boundaries, including periods with zero logs. `eligibility` is normal, initial_partial, or transitional. |
| `CalendarRule` | Unique `id` and `effectiveStartDay`; `weekStartWeekday` (ISO Monday=1), `createdAt`. | Activated weekly boundary history. Global, so deleting one habit never deletes another's calendar rules. |
| `AppSettings` | Singleton key; default Monday; optional pending weekday/effective day; monotonically increasing `revision`. | Global settings, pending week-start replacement, stale-work detection. |
| `ReminderConfiguration` | One per Activity with an enabled flag, numeric target, `learningStartedAt`, and `learningStartDay`. | The start instant and day identify the learning window for the active target. Added in schema V2. |
| `ReminderSlot` | Required configuration; unique `(activityID, slotIndex)`; `seedMinute`, `effectiveMinute`, optional `lastAdjustedDay`. | One slot for weekly habits, N ordered slots for daily. Minutes 0–1439. Apply at most once per strictly later local day to enforce the movement cap even during clock rollback. Added in V2. |
| `PendingReminderSeed` | Required Activity; unique `(activityID, slotIndex)`; `minute`. | Seed times attached to a deferred daily-target increase during clock rollback. Added in V2. |
| `AdjustmentNotice` | Unique `id`; required Activity; `createdAt`, `reason`, optional `acknowledgedAt`. | One notice for all changes applied by one learning calculation. Added in V2. |
| `AdjustmentChange` | Required notice; `slotIndex`, `oldMinute`, `newMinute`. | Typed details of a notice, rather than a formatted string as source data. Added in V2. |

Cascade Activity deletion to completions, receipts, periods, reminder configuration/slots,
pending seeds, and notices/changes. Deleting a single Completion keeps its receipt; retrying
that old operation reports that it was already processed and never resurrects the entry.
Reusing an operation ID for different original input fails as an operation conflict.

Index completions by activity/date and periods by activity/start date. No report cache is needed
initially. Derive progress from logs and targets, then refresh snapshots after committed changes.

## Period materialization and historical truth

Before reading current state or mutating it, advance the calendar through the captured local
date. Generate every missing planned period from tracking start, including empty days/weeks;
apply any pending target or calendar boundary at its effective date. Persist completed periods'
targets and boundaries. A multi-month absence requires no background process to fill the gaps.

Store only periods through the current date, plus pending settings. Reminder planning projects
future periods as values without prematurely closing or persisting them. The app must not
materialize decades of speculative future plans merely to schedule notifications.

- A daily edit changes the current open day's target. A weekly edit uses the current period's
  midpoint and stages the next target when late. Persist the effective date returned to the UI.
- For a normal week, calculate midpoint by local calendar components: start + three calendar
  days + 12 hours. Do not use a fixed number of elapsed seconds across DST. For a transition,
  use the midpoint of its local start/end date-time coordinates.
- When week start changes, replace any unactivated setting; truncate or extend the current
  open week to the next new weekday boundary. Move a pending weekly target to that boundary.
  Preserve closed boundaries. Daily periods are untouched.
- Closing is permanent. If travel/clock rollback returns to a stored closed period, logging
  still uses the captured date and that period's preserved target; edits select the first
  unclosed period. Never create a duplicate period to accommodate rollback.
- Backfills extend tracking to the earlier date at midnight. Generate only the newly included
  earlier periods with `initialTarget`; keep existing target history. Use the earliest calendar
  rule backward before recorded calendar history. Re-evaluate initial partial eligibility.
  Deleting an early entry does not shorten the tracking interval.
- Within a period, transitional eligibility takes precedence over initial-partial eligibility;
  either is excluded from historical rates. CSV status uses those values before checking open
  versus complete. This gives the single CSV status column an unambiguous precedence.

## Shared value contracts

These are planned names/contracts, not implementation code. Task-specific methods appear in
the [implementation plan](../superpowers/plans/2026-11-10-habit-tracker.md).

| Type | Contents |
| --- | --- |
| `CalendarDay` | Validated year/month/day; comparable; canonical string; calendar addition without UTC conversion. |
| `ClockReading` | `instant: Date`, `timeZoneID: String`, `localDay: CalendarDay`, `localMinute: Int`; capture once per operation. Keep seconds in the instant for exact midpoint comparisons. |
| `DayRange` | Inclusive start/end CalendarDay; constructor rejects inversion. |
| `Cadence` | `daily` or `weekly`. |
| `ActivitySnapshot`, `CompletionSnapshot`, `GoalPeriodSnapshot` | Immutable equivalents of the relevant persisted fields above. |
| `TimelineState` | Activities, periods, activated calendar rules, pending calendar setting. No managed objects or notification requests. |
| `StoreSnapshot` | Timeline, completions, reminder configurations/slots, notices, `revision`. |
| `SnapshotQuery` | Optional `activityID` and `DayRange`; nil means all. |
| `GoalProgress` | `rawCount`, `creditedUnits`, `target`, `isMet`; fraction derived from credited/target. |
| `HabitDraft` | Validated name, symbol, cadence, numeric target. Creation time comes from ClockReading. |
| `LogRequest` | `activityID`, `operationID`, `assignedDay`, optional `occurredAt`, `captureTimeZoneID`, source app/shortcut/manual. |
| `CompletionEdit` | `completionID`, `assignedDay`, optional `occurredAt`, `captureTimeZoneID`. |
| `TargetEdit` | `activityID`, target, added slot seed minutes (empty unless required). |
| `ReminderEdit` | `activityID`, enabled flag, ordered seed minutes. |
| `HabitCommand` | create, rename/change icon, log, edit/delete completion, edit target, change week start, delete activity, edit reminders, acknowledge notice, refresh. Associated inputs use the types above and UUIDs. |
| `MutationReceipt` | Saved revision, optional affected activity/completion ID, `wasReplay`, optional effective target date. No optimistic success. |
| `HabitError` | validation with field/reason, activityUnavailable, completionUnavailable, operationConflict, storeUnavailable, saveFailed. UI translates to actionable copy. |
| `ReportRequest` | Activity ID, weekly/monthly/yearly granularity, selected period anchor date. |
| `HabitReport` | `creditedUnits`, `targetUnits`, optional exact `adherence`, optional `displayPercent`, `goalsMet`, `eligibleCount`, `openProgress`, `partialProgress`, `calendarDays`, `breakdown`, `weeklyGoals`, optional `trend` with both compared date ranges. |
| `LearningDecision` | Activity ID, zero or more slot changes, calculation day and reason; no change produces no notice. |
| `PlannedNotification` | Stable ID, activity ID, slot, intended local day/minute, resolved fire instant, gentle title/body. |
| `ScheduleOutcome` | Current authorization, successfully reconciled revision, earliest/latest scheduled dates, optional scheduling error. |

Validate user/intent inputs at service entry. Reject invalid bounds, empty names, future assigned
dates, and supplied future occurrence instants. Don't infer a timestamp for a date-only entry.
Keep raw counts and exact fractions; round only presentation. Use a captured timezone for
historical wall-clock learning, not the current travel timezone.

Learning minimizes the total shortest circular distance over integer wall-clock minutes
0–1439. Choose a minimizing minute closest to the existing reminder; if still tied, choose
the lower minute. Round to the nearest five minutes, with exact rounding ties forward modulo
1440. Validate the final slot ordering and 30-minute spacing, including across midnight.
This makes the spec's circular-median and rounding rules deterministic without an ML service.

## Notification consistency

`NotificationScheduler` has a single coalescing worker. Requests while a reconciliation is
running mark it dirty; they do not start a second interleaved queue rewrite. Read the latest
committed snapshot, derive the next 28 days/earliest 60 requests, inspect the system's pending
requests, remove stale app-owned IDs, and add/replace required IDs. If the database revision
changed while awaiting the OS, repeat with the latest snapshot before declaring reconciliation
complete. Retry on next activation if interrupted or failed.

Use stable IDs containing activity ID, slot, local date, and resolved fire instant. A timezone
change therefore replaces an old instant. Enumerate all app-owned pending IDs to remove
notifications for already deleted activities; no database tombstone or remote queue is needed.
Only future eligible times are scheduled. Notification taps navigate without logging.

No background-refresh entitlement is necessary for correctness. Foreground activation and
shortcut logging replenish the queue; process any lifecycle opportunity iOS actually provides.
The accepted finite-coverage limitation remains visible in reminder settings.

## Storage failures, migration, and recovery

Use Apple's [persistent-store file protection option](https://developer.apple.com/documentation/coredata/nspersistentstorefileprotectionkey)
with `completeUntilFirstUserAuthentication`. If protected data is unavailable, show a recoverable
unavailable state and retry after unlock. Do not create a replacement database at another path.

Model V1 is the tracking/history schema. Add reminder entities and necessary relationships in
V2 during the reminder stage; retain V1 as an immutable bundled model and test an actual V1→V2
migration. Enable automatic migration only for changes Core Data can infer; future incompatible
changes need an explicit migration before shipping. Never delete/recreate a store on failure.

Open and validate the store before enabling logging. A failed open/migration shows an actionable
error with retry, keeps the original store intact, and exposes no false empty/success state.
Restore tests cover the complete SQLite store, including committed WAL data through supported
store handling; a raw copy of the main `.sqlite` file while open is not a backup test.

Temporary CSVs live outside persistent data, receive normal file protection, and are removed
after sharing/cancellation and cleaned on next launch after interruption. App deletion, old
backup copies, and files already shared follow the product specification's stated boundaries.

## Review decision

The owner is being asked to accept Core Data, this model, and the staged plan before code is
written. Device signing, installed simulator runtime, actual iOS 26 shortcut labels, restore,
and phone transfer remain execution checks; no successful platform validation is claimed here.
