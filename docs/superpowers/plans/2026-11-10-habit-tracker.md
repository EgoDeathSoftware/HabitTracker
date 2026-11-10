# Habit Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the specified local-only iPhone habit tracker in testable stages, beginning
with persistent in-app and Home Screen logging on the owner's phone.

**Architecture:** Core Data with a local SQLite store, one serialized writer, and immutable
domain snapshots. SwiftUI and the App Intent share commands; pure functions calculate goals,
periods, reports, learning, and export rows. Local notifications are derived after commit.

**Tech Stack:** Swift, SwiftUI, Foundation, Core Data, App Intents, UserNotifications,
Swift Testing, XCTest/XCUITest; Apple frameworks only. iOS 26 minimum.

**Spec:** [SPEC.md](../../../SPEC.md), accepted version 1.0.
**Design:** [Storage, model, and shared contracts](../../architecture/0001-local-storage-and-domain.md).
**Tests:** [All 22 acceptance criteria and device procedures](../../testing/acceptance-matrix.md).
**Status:** Ready for owner review. This document contains planned interfaces/assertions only;
no app scaffold, implementation, or tests have been created. Development is not authorized yet.

## Global Constraints

- "Platform: Native iPhone application using Swift and SwiftUI, iOS 26 or later."
- "All app-owned data and computation stay on the device."
- "No accounts, sign-ups, application servers, cloud databases, synchronization, remote
  analytics, advertising SDKs, or external AI services."
- "Setup, logging, editing, statistics, reminder calculation, and export work offline."
- "Apple-managed device backups, including iCloud Backup, are allowed under the device owner's control."
- "Daily: 1–10 completions. Weekly: 1–7 distinct days."
- "Persist before showing success."
- "Use the Gregorian calendar."
- "Multiple logs on one date earn one day of credit."
- "Past targets stay fixed; correcting past logs still changes past progress."
- "Do not claim that a particular number of days guarantees habit formation."
- "CSV is a report, not a backup format."
- Preserve the full accepted spec, including its 28/56-day learning windows, five-date minimum,
  15-minute threshold, 30-minute daily adjustment/spacing limits, and 28-day/60-request queue.
- No third-party dependency, cloud entitlement, widget, backend, CSV import, or App Store launch.
- Repository standards apply: functions ≤100 lines, complexity ≤8, ≤5 positional parameters,
  code lines ≤100 characters, actionable errors, zero unexplained tool warnings.

## Review Focus

1. Retry after a committed log, concurrent taps, or correction of that log must neither duplicate
   nor resurrect it — T03/T04 `replayAfterRestartOrDeletion` and `retryAndConcurrency`.
2. Months without launch and no completions must still yield every planned period and its
   historical target — T02 `materializeEmptyGap`.
3. Midnight, DST, travel, and clock rollback must not rewrite dates or closed targets — T02
   `closedPeriodRollback`, T04 `travelKeepsAssignedDay`, T08 `dstOnce`.
4. An in-flight notification rebuild must not restore stale reminders after a new log/deletion —
   T08 `latestRevisionWins`.
5. A failed save/open/migration must preserve the old data and never show false success or
   an empty replacement store — T03 `saveFailureIsAtomic`, T10 `failureDoesNotReset`.

---

## Stage gates and order

This is one integrated app plan: the store and period model are shared by all later features.
Separating those into unrelated subsystem plans would obscure the same transaction boundaries.

| Stage | Tasks | Reviewable result / gate |
| --- | --- | --- |
| A — Tracking and shortcuts | T01–T05 | On physical iPhone: create, log in app and Home Screen, correct history, restart, verify persistence. Complete D2 before building later features. |
| B — Progress reports | T06 | Weekly/monthly/yearly totals proven against fixed history, including changed targets and empty periods. |
| C — Adaptive reminders | T07–T08 | Local learning and notices, then OS scheduling; device D3 with no logging dependency on notifications. |
| D — CSV export | T09 | Offline date-range export with zeros and historical targets; D5 interoperability. |
| E — Data continuity and full acceptance | T10–T11 | Migration/restore/transfer evidence, offline end-to-end and accessible primary flows. Record any unavailable device checks explicitly. |

Do not advance through a failing stage gate. If OS behavior contradicts the design, record the
specific evidence and propose a correction before changing a product requirement. Never count
a simulator-only shortcut or backup test as the required physical-device result.

## Planned file structure

Create files only in their owning task. The names below are the implementation map, not files
that already exist. One app/test/UI-test target in a native Xcode project; no project generator.

| Paths | Responsibility / first task |
| --- | --- |
| `HabitTracker.xcodeproj/project.pbxproj`, `HabitTracker.xcodeproj/xcshareddata/xcschemes/HabitTracker.xcscheme` | App + hosted Swift Testing + UI test targets, shared scheme, iOS 26 deployment; T01. |
| `HabitTracker/App/HabitTrackerApp.swift`, `AppEnvironment.swift`, `AppRouter.swift` | Composition, store-ready/error states, lifecycle refresh, navigation; T01/T04/T05. |
| `HabitTracker/Domain/CalendarDay.swift`, `DomainTypes.swift`, `GoalRules.swift`, `PeriodRules.swift` | Typed snapshots/commands, deterministic dates, credit and historical plans; T01/T02. |
| `HabitTracker/Persistence/PersistenceController.swift`, `HabitStore.swift`, `ManagedObjectMapping.swift`, `HabitTracker.xcdatamodeld/` | Single-context transactions, value mapping, versioned model; T03. |
| `HabitTracker/Activities/ActivityActions.swift`, `ActivityListView.swift`, `ActivityEditorView.swift`, `ActivityDetailView.swift`, `HistoryEditorView.swift`, `TargetEditorView.swift` | Shared commands and native activity/history UI; T04. |
| `HabitTracker/Settings/SettingsView.swift` | Week start, later export entry; T04/T09. |
| `HabitTracker/Shortcuts/ActivityEntity.swift`, `LogActivityIntent.swift`, `HabitShortcutsProvider.swift`, `ShortcutGuideView.swift` | Stable entity lookup, action, discovery, bundled guide; T05. |
| `HabitTracker/Reports/ReportCalculator.swift`, `ReportsView.swift`, `ActivityCalendarView.swift` | Exact report calculations and accessible presentation; T06. |
| `HabitTracker/Reminders/ReminderLearning.swift`, `ReminderSettingsView.swift`, `AdjustmentNotesView.swift`, `NotificationPlanner.swift`, `NotificationScheduler.swift`, `NotificationClient.swift` | On-device adaptation, notes, queue projection/reconciliation; T07/T08. |
| `HabitTracker/Export/CSVExporter.swift`, `ExportView.swift` | Streaming daily-summary CSV and share lifecycle; T09. |
| `HabitTrackerTests/Fixtures/FixtureFactory.swift`, `LegacyStoreV1.json` | Deterministic clocks/history and frozen V1 migration data; T01/T03. |
| `HabitTrackerTests/{GoalRules,PeriodRules,HabitStore,History,Intent,Report,ReminderLearning,NotificationPlanner,Scheduler,CSVExport,Migration,Restore}Tests.swift` | Behavioral suites owned by the corresponding task. |
| `HabitTrackerUITests/{HistoryFlow,ShortcutGuide,OfflineFlow,AccessibilityFlow}Tests.swift` | Primary flow tests; T04/T05/T11. |
| `HabitTracker/Resources/Assets.xcassets`, `Localizable.xcstrings`, `PrivacyInfo.xcprivacy` | Minimal app assets, UI strings, accurate required-reason declarations if applicable; T01/T11. |
| `docs/testing/results/<date>-<build>.md` | Actual evidence and remaining limitations; beginning T05. |

Use built-in symbols for habit icons. Use a native activity list, detail/history screen, reports
screen, and settings screen. UI components may be split further when responsibility warrants;
do not add a generic repository framework, remote layer, or speculative dependency injection kit.

## Test execution conventions

At implementation start, inspect the installed Xcode and simulator runtimes. Xcode 27.2 and the
iOS 27.2 SDK were observed during specification work; no simulator runtime or signing setup was
validated. Use the existing toolchain if it supports deployment to iOS 26. Verify compatibility
on the owner's supported iOS 26 device, not only a newer simulator.

Select an installed iPhone simulator UDID and set `HABIT_SIMULATOR_UDID` for this execution shell.
Use `xcrun simctl list devices available` and `xcodebuild -showdestinations` with
`DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; do not invent an available runtime.
Device signing/team/bundle identifier are local setup checks in T05, not preapproved account
changes or distribution work. No dependency installation or toolchain upgrade is assumed.

Commands below use this form, replacing only the named suite as each task specifies:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project HabitTracker.xcodeproj -scheme HabitTracker \
  -destination "platform=iOS Simulator,id=$HABIT_SIMULATOR_UDID" \
  -only-testing:HabitTrackerTests/GoalRulesTests
```

Success means exit 0, the intended tests actually executed and passed, and no build/compiler
warnings. A missing implementation compile error is an acceptable initial red test; a broken
destination, signing error, or zero tests executed is not evidence that a behavior test failed.
Each task uses focused suites; expand testing only for changed dependencies or new concerns.
Store tests use temporary **on-disk SQLite**, not only Core Data's in-memory store.

For each task, implement test assertions before production behavior, run red, implement, run
green, inspect the diff, then commit only that task's files with the listed subject. Test snippets
below specify named tests and observable results, not full implementation bodies. The prose
defines their inputs. Do not create application/test files while this remains a planning task.
Some assertions use named test probes, such as `pendingActivityIDs` or `originalFixtureDigest`,
to inspect observations across service calls. Those are test-helper projections of the declared
contracts, not additional production wrapper types or persisted properties.

## T01 — Validated dates and goal credit

**Files:** Create the T01 project/app/domain/resources/fixture paths above and
`HabitTrackerTests/GoalRulesTests.swift`. Use an empty launchable SwiftUI host until T04.

**Interfaces:** Produces `CalendarDay`, `ClockReading`, `DayRange`, `Cadence`, snapshot and
command value types from the design; `GoalRules.progress(period: GoalPeriodSnapshot,
completions: [CompletionSnapshot]) -> GoalProgress`. No persistence/framework types in rules.

- [ ] Create the app/test targets and shared scheme with Swift concurrency checking enabled;
  record compiler/runtime versions. Build the empty host without cloud capabilities/dependencies.
- [ ] Write `dailyCredit` and `weeklyDistinctDays`: daily targets 1/2 with counts 2/1/3; weekly
  target 2 with two logs Monday Nov 9 and one Tuesday Nov 10, 2026. Assert:
  ```swift
  #expect(oneDaily.creditedUnits == 1 && oneDaily.rawCount == 2)
  #expect(twoDailyPartial.creditedUnits == 1 && twoDailyPartial.target == 2)
  #expect(twoDailySurplus.creditedUnits == 2)
  #expect(mondayOnly.creditedUnits == 1 && !mondayOnly.isMet)
  #expect(mondayAndTuesday.creditedUnits == 2 && mondayAndTuesday.isMet)
  ```
  Also assert constructors reject invalid Gregorian dates, daily 0/11, weekly 0/8, and blank
  names; leap day 2028-02-29 is valid. Preserve duplicate names and Unicode.
- [ ] Run the convention command with `GoalRulesTests`; observe the intended red assertions.
- [ ] Implement validated values and credit rules, preserving raw logs and capping credits.
- [ ] Re-run `GoalRulesTests`; require green and zero warnings. Inspect dependency/capability list.
- [ ] Commit: `Add validated calendar values and habit credit rules`.

## T02 — Target history and calendar boundaries

**Files:** Create `HabitTracker/Domain/PeriodRules.swift`,
`HabitTrackerTests/PeriodRulesTests.swift`; extend `DomainTypes.swift` and `FixtureFactory.swift`.

**Interfaces:** Consumes T01 values. Produces `PeriodRules.advance(state: TimelineState,
at: ClockReading) -> TimelineState`, `editTarget(state: TimelineState, edit: TargetEdit,
at: ClockReading) throws -> TimelineState`, `changeWeekStart(state: TimelineState,
weekday: Int, at: ClockReading) -> TimelineState`, and `extendTracking(state: TimelineState,
activityID: UUID, to: CalendarDay) -> TimelineState`. Returned state includes effective pending dates.

- [ ] Write `weeklyMidpoint`, `pendingReplacementAndActivation`, `materializeEmptyGap`,
  `calendarEdges`, `closedPeriodRollback`, and `backfillInitialTarget`. Use America/New_York,
  Monday Nov 9, 2026, weekly current target 2, replacement 4. Assert Thursday noon applies 4
  now; one second later keeps 2 and stages 4 for Nov 16. Replace pending with 5; saving 2
  cancels. Daily edit applies today. After two missed boundaries, activation happens once.
  For the empty-gap fixture, create a daily habit Jan 1 at midnight, then reopen Feb 1 at noon.
  ```swift
  #expect(atMidpoint.activities[0].effectiveTarget == 4)
  #expect(afterMidpoint.activities[0].effectiveTarget == 2)
  #expect(afterMidpoint.activities[0].pendingTarget == 4)
  #expect(afterMidpoint.activities[0].pendingTargetStartDay == CalendarDay("2026-11-16"))
  #expect(emptyGap.periods.count == 32) // Jan 1 through Feb 1, 2026, daily; Feb 1 open
  #expect(emptyGap.closedPeriods.count == 31)
  #expect(rollback.closedTarget == 2 && rollback.firstUnclosedTarget == 4)
  #expect(rollback.duplicatePeriodCount == 0)
  ```
  Test creation noon partial vs creation midnight eligible; leap day; midnight end-exclusive;
  Monday→Sunday on Nov 10 ends transition Nov 15; replace pending weekday before activation;
  move a pending target with the new boundary; preserve all closed weeks. Earlier backfill
  extends to midnight using initial targets and never shrinks after deletion. Check a normal
  week crossing DST still uses Thursday noon and test a transition's own midpoint.
- [ ] Run convention command with `PeriodRulesTests`; confirm red on the specified rules.
- [ ] Implement the four interfaces with explicit period materialization and monotonic closure,
  including empty periods and future projection without persistence. Use architecture status precedence.
- [ ] Re-run `PeriodRulesTests` and `GoalRulesTests`; require all stated edges green.
- [ ] Commit: `Define historical targets and calendar transitions`.

## T03 — Transactional local store

**Files:** Create T03 persistence paths, model
`HabitTracker/Persistence/HabitTracker.xcdatamodeld/HabitTrackerV1.xcdatamodel/contents`,
`.xccurrentversion`, `HabitTrackerTests/HabitStoreTests.swift`, and `Fixtures/LegacyStoreV1.json`.

**Interfaces:** Consumes T01/T02. Produces `PersistenceController.open(storeURL: URL) async
throws -> PersistenceController`; actor `HabitStore.execute(_ command: HabitCommand,
at: ClockReading) async throws -> MutationReceipt`; `snapshot(for query: SnapshotQuery,
at: ClockReading) async throws -> StoreSnapshot`. Reads advance/materialize history transactionally.

- [ ] Write `retryAndConcurrency`, `replayAfterRestartOrDeletion`, `saveFailureIsAtomic`,
  `protectedStoreUnavailable`, and `reopenPreservesHistory` using temporary SQLite files.
  Same original operation twice produces one log; two concurrent independent operations
  produce two. Reuse with different payload throws operationConflict. Reopen after saved
  operation but before caller acknowledgment, then retry: still one. Fault-inject at save.
  ```swift
  #expect(retried.completions.count == 1 && replay.wasReplay)
  #expect(concurrent.completions.count == 2)
  #expect(afterFailedSave.completions.isEmpty)
  #expect(afterFailedSave.timeline == beforeFailedSave.timeline)
  #expect(reopened.timeline == saved.timeline)
  ```
  Verify no receipt/period partial writes, no managed objects cross queues, unavailable store
  is an error (not an empty snapshot), and distinct operation receipts survive context reload.
- [ ] Run convention command with `HabitStoreTests`; observe red behavioral failures.
- [ ] Implement model V1, queue-confined mapping and atomic command execution/rollback. Protect
  store files, retain backup eligibility, validate payload reuse, and preserve receipts when
  a completion is deleted. Retain the frozen V1 model/fixture for real V2 migration tests.
- [ ] Re-run `HabitStoreTests`; reopen each store from disk, not merely the same context.
- [ ] Commit: `Persist habit commands and history atomically`.

## T04 — Usable in-app tracking and correction

**Files:** Create T04 Activities/Settings paths, `AppEnvironment.swift`,
`HabitTrackerTests/HistoryTests.swift`, `HabitTrackerUITests/HistoryFlowTests.swift`; wire app host.

**Interfaces:** Consumes HabitStore. Produces `ActivityActions.apply(_ command: HabitCommand)
async throws -> MutationReceipt`, `logNow(activityID: UUID, source: CompletionSource) async
throws -> MutationReceipt`, and `retryLog(_ request: LogRequest) async throws -> MutationReceipt`.
It captures time/ID once, retains a failed request for explicit retry, then refreshes UI from saved
snapshots. `CompletionSource` is app/shortcut/manual as defined by LogRequest.

- [ ] Write `correctionsRecalculate`, `travelKeepsAssignedDay`, `cascadeDelete`, and the
  delete-after-retry part of `replayAfterRestartOrDeletion`. Move a log across a week boundary;
  backfill without a time; delete its original operation's completion then retry.
  ```swift
  #expect(dateOnly.occurredAt == nil && dateOnly.source == .manual)
  #expect(moved.wasTimeOrDateEdited)
  #expect(afterTravel.assignedDay == beforeTravel.assignedDay)
  #expect(afterReplayOfDeletedLog.completions.isEmpty)
  #expect(afterDeletion.activityOwnedRowCount == 0)
  #expect(afterDeletion.otherActivity == beforeDeletion.otherActivity)
  ```
  UI `deleteCancelAndConfirm` verifies named warning/cancel/confirm; add create/rename/icon,
  target effective-date preview, pending-cancel, invalid future input, and save-error feedback.
- [ ] Run `HistoryTests`, `HabitStoreTests`, and UI convention command targeting
  `HabitTrackerUITests/HistoryFlowTests`; confirm the intended failures.
- [ ] Build list/detail/editor/history/settings flows. Refresh after saved mutations; do not
  optimistically increase counts. Target/weekday edits show effective dates. Reject future
  dates/instants, warn before extending tracking, and explain complete-history deletion.
  Add non-color progress, VoiceOver labels, Dynamic Type, and store retry state now.
- [ ] Re-run those suites; cold relaunch a simulator and verify counts/settings persist.
- [ ] Commit: `Add activity management and editable local history`.

## T05 — Home Screen logging and bundled setup guide

**Files:** Create T05 Shortcuts paths, `AppRouter.swift`, `HabitTrackerTests/IntentTests.swift`,
`HabitTrackerUITests/ShortcutGuideTests.swift`; update ActivityDetailView and app composition.

**Interfaces:** Consumes ActivityActions and snapshots. Produces `ActivityEntity` with UUID
identity and display name/symbol/short UUID suffix for duplicate names; entity query resolves
only existing activities. `LogActivityIntent.perform() async throws -> some IntentResult`
has a required fixed ActivityEntity parameter and exact displayed action name **Log Activity**.
`AppRouter.showActivity(id: UUID, confirmation: MutationReceipt?)` only navigates/renders.

- [ ] Write `confirmationAfterSave`, `noSuccessOnSaveFailure`, `fixedActivityParameter`, and
  `identitySurvivesRenameAndDeletion` through the shared command path.
  ```swift
  #expect(afterOneInvocation.completions.count == 1)
  #expect(afterRenderingConfirmation.completions.count == 1)
  #expect(resolvedAfterRename.id == originalActivityID)
  #expect(staleInvocation.error == .activityUnavailable)
  #expect(failedInvocation.confirmation == nil)
  ```
  Add UI `oneOccurrenceCopy` and `repeatableOfflineAndNoSideEffects`: guide accessible for
  each saved activity, includes every SPEC §6 step/troubleshooting topic, creates zero logs.
- [ ] Run `IntentTests` and `HabitTrackerUITests/ShortcutGuideTests`; confirm red.
- [ ] Implement foreground-supported App Intent in the app target using current iOS 26 runtime
  APIs. Generate operation ID once inside each invocation; reuse it for internal retries.
  Do not store a constant operation ID as a shortcut parameter. Do not claim Apple's independent
  future invocations share a retry identity. Entity query and failures never recreate a habit.
  Bundle the guide, with actual shipped names and fixed-parameter instructions, in native UI.
- [ ] Re-run both suites and perform D2 on the supported iPhone. Check actual Shortcuts labels,
  cold launch, identity after rename, deleted activity error, and one-tap save/confirmation.
  Verify restart persistence, then record build/device/evidence. Resolve signing locally without
  distribution changes. If device access is unavailable, record stage A as blocked for that gate.
- [ ] Commit: `Add Home Screen logging and in-app shortcut guidance`.

## T06 — Weekly, monthly, and yearly reports

**Files:** Create T06 Reports paths and `HabitTrackerTests/ReportTests.swift`; wire reports entry.

**Interfaces:** Consumes snapshots/GoalRules; produces `ReportCalculator.report(snapshot:
StoreSnapshot, request: ReportRequest, at: ClockReading) -> HabitReport`. Calendar also feeds detail.

- [ ] Write `eligiblePeriodsAndWeightedRate`, `crossMonthAndYear`, and
  `completedPeriodComparisons`. Two eligible periods, targets 1/3 and credits 1/2 give 75%;
  empty history nil; open/initial/transitional excluded. The Nov 30–Dec 7 week belongs to Dec;
  Dec 28–Jan 4 belongs to next year. Current November report trend names September/October,
  never partial November vs all October; unavailable without sufficient completed history.
  Use separate fixtures for the cross-month and cross-year attribution assertions.
  ```swift
  #expect(weighted.creditedUnits == 3 && weighted.targetUnits == 4)
  #expect(weighted.displayPercent == 75)
  #expect(noHistory.adherence == nil)
  #expect(december.weeklyGoals.count == 1 && november.weeklyGoals.isEmpty)
  #expect(year2027.weeklyGoals.count == 1 && year2026.weeklyGoals.isEmpty)
  ```
  Add weekly daily-habit summary with today separate; weekly blank dates not failures;
  target-weighted rates without intermediate rounding and capped surplus; ten-year/25-habit fixture.
- [ ] Run convention command with `ReportTests`; confirm red.
- [ ] Implement exact fractions, completed-period attribution, breakdowns, accessible calendar,
  and native reports. Derive from snapshots off the main actor; invalidate view state on revision.
- [ ] Re-run `ReportTests`; perform report portions of D4 and record responsiveness on fixture.
- [ ] Commit: `Add historical habit reports and calendars`.

## T07 — Reminder settings, learning, and adjustment notices

**Files:** Create learning/settings/notes paths, model `HabitTrackerV2.xcdatamodel/contents`,
`HabitTrackerTests/ReminderLearningTests.swift`, `MigrationTests.swift`; update current model,
mapping/store, TargetEditorView, DomainTypes and ActivityDetailView for reminder fields.

**Interfaces:** Consumes StoreSnapshot/ClockReading; produces `ReminderLearning.evaluate(snapshot:
StoreSnapshot, at: ClockReading) -> [LearningDecision]`. HabitStore applies decisions atomically
with relevant mutations/refresh, preserving per-day adjustment limits and notices in V2.
ReminderEdit and TargetEdit provide seed times; effective target change resets the learning epoch.

- [ ] Write `slotsThresholdsAndNotices`, `midnightCircularMedian`, and
  `targetChangeResetsSamples`. Use daily two-slot seeds 09:00/18:00, five eligible completed
  dates at 10:00/19:00; moves become 09:30/18:30 with one grouped note. Four dates leave seeds.
  ```swift
  #expect(fourDates.changes.isEmpty)
  #expect(fiveDates.newMinutes == [570, 1110])
  #expect(repeatedSameDay.changes.isEmpty)
  #expect(applied.notices.count == 1 && applied.notices[0].changes.count == 2)
  #expect(afterTargetChange.qualifyingDateCount == 0)
  ```
  Cover exclusion of manual/edited/current-day/out-of-window logs; weekly earliest eligible
  log, five samples in 56 days; daily first N fully qualifying logs in 28 days; surplus ignored.
  Midnight samples 23:50/23:55/00:00/00:05/00:10 median→00:00. Resolve equal-distance ties
  deterministically by earliest minute after choosing closest to current time. Round five-minute
  ties forward modulo 1440. <15-minute difference unchanged; ≥15 changes; daily cumulative
  move ≤30; apply at most once per strictly later local day, including during rollback;
  no reorder or <30-minute slot gap, including last-to-first across midnight.
  Test target decrease retains earliest slots, increase requires new seeds, disabled by default.
- [ ] Add `v1ToV2PreservesData` using frozen V1 model/fixture: same IDs, logs, targets, calendar
  settings and pending changes, reminders initially off. Run `ReminderLearningTests` and
  `MigrationTests`, confirming red before implementation.
- [ ] Implement circular median/gradual updates, schema V2 migration, seed validation and
  acknowledgment UI. Retained times seed the new epoch at actual target activation, even
  after reopening. Persist notices before display; acknowledgment survives restart. No OS
  notification scheduling yet; settings state clearly reflects pending delivery integration.
- [ ] Re-run both suites and affected `HistoryTests`; verify fixture notice display and large text.
- [ ] Commit: `Learn local reminder times and preserve adjustment notices`.

## T08 — Local notification delivery and reconciliation

**Files:** Create NotificationPlanner/Scheduler/Client paths,
`HabitTrackerTests/NotificationPlannerTests.swift`, `SchedulerTests.swift`; update composition,
ActivityActions, app lifecycle, settings permission handling, and notification navigation.

**Interfaces:** `NotificationPlanner.plan(snapshot: StoreSnapshot, at: ClockReading)
-> [PlannedNotification]`. `NotificationScheduler.reconcile() async -> ScheduleOutcome` coalesces
requests and retries the newest revision. `NotificationClient` boundary exposes `pendingIDs()
async -> Set<String>`, `remove(ids: Set<String>) async`, `add(_ request: PlannedNotification)
async throws`, `authorization() async -> NotificationAuthorization`, and `requestAuthorization()
async throws -> Bool`; authorization is notDetermined/denied/authorized/provisional.

- [ ] Write `suppression`, `correctionRestoresFutureOnly`, `dstOnce`,
  `deniedFailureCapacityAndReplay`, `failureKeepsSavedLog`, `deletedActivityReconciliation`,
  and `latestRevisionWins`.
  Inject a controllable notification client; suspend an add, commit a log/deletion, resume, then
  verify the newest snapshot wins. More than 60 candidates sorted by fire instant, activity
  UUID string, slot and stable ID yield exactly earliest 60 within next 28 calendar days.
  ```swift
  #expect(capped.count == 60 && Set(capped.map(\.id)).count == 60)
  #expect(afterTodayWeeklyLog.requestsForToday.isEmpty)
  #expect(afterDailyGoal.requestsForToday.isEmpty)
  #expect(afterSchedulerFailure.savedLogCount == 1)
  #expect(afterConcurrentDeletion.pendingActivityIDs.contains(deletedID) == false)
  #expect(dstRepeatedTime.requests.count == 1)
  ```
  Test denial/request error, repeated reconciliation, timezone replacement, stable tie order,
  disabled/deleted habits, current slot already elapsed, correction only restores future times,
  pending target/week transitions in projected future, and no overdue burst after queue expiry.
  DST gap uses next valid time (New York 2026-03-08 02:30→03:00); repeated 01:30 schedules
  only its first occurrence. Notification tap must not call any logging command.
- [ ] Run `NotificationPlannerTests` and `SchedulerTests`; confirm red without real delivery sleeps.
- [ ] Implement permission on first enable, next-28-day planning, earliest-60 budget and a single
  coalescing reconciliation worker. Save first, then schedule; inspect/replace stale pending IDs.
  Hook logs/corrections/targets/settings/deletion/activation/observed clock changes and any granted
  lifecycle opportunity. Explain finite coverage in settings. No background execution guarantee.
- [ ] Re-run both suites, `IntentTests`, and D3 on phone; document OS capacity/delivery observations
  separately from app queue-policy assertions. Confirm failure cannot erase or hide a saved log.
- [ ] Commit: `Schedule and reconcile adaptive local reminders`.

## T09 — Date-range CSV export

**Files:** Create T09 Export paths and `HabitTrackerTests/CSVExportTests.swift`; wire SettingsView.

**Interfaces:** `CSVExporter.export(snapshot: StoreSnapshot, range: DayRange, at: ClockReading,
directory: URL) async throws -> URL`; output uses SPEC §11's exact column order. Stream UTF-8
rows off the main actor, check task cancellation while writing, and delete an incomplete file.

- [ ] Write `rangeAndEscaping` and `assignedDatesRemain`: an activity tracked from Nov 9 through
  Nov 11 produces three rows with raw counts 1/0/2. An earlier start excludes untracked dates;
  use period-specific targets and all current habits. Validate weekly 0/1 observations remain
  uncapped, daily credit capped, other cadence column empty, and status precedence as designed.
  ```swift
  #expect(parsed.map(\.rawCount) == [1, 0, 2])
  #expect(parsed.map(\.date) == ["2026-11-09", "2026-11-10", "2026-11-11"])
  #expect(formulaNameCell == "'=1+1")
  #expect(storedName == "=1+1")
  #expect(cancelledExport.remainingTemporaryFiles.isEmpty)
  ```
  Include Unicode, embedded CR/LF, commas, quotes, and names with whitespace/control prefixes
  before = + - @. Treat text as a whole cell: neutralize potentially interpreted formula text
  with a leading apostrophe, then standard CSV quote/escape. Do not modify stored names.
  Test inverted/future-end/empty ranges, share cancel, interrupted-launch cleanup and large fixture.
- [ ] Run convention command with `CSVExportTests`; confirm red.
- [ ] Implement selection/validation, streaming export, no-row feedback, and system sharing with
  file lifetime through completion/cancel. Keep user-selected destinations outside app control.
- [ ] Re-run `CSVExportTests`, perform D5, and verify export responsiveness/cancellation.
- [ ] Commit: `Export historical habit summaries as safe CSV`.

## T10 — Migration and data-continuity verification

**Files:** Extend MigrationTests, create `HabitTrackerTests/RestoreTests.swift`; update
persistence error handling as required and `docs/testing/results/<date>-<build>.md`.

**Interfaces:** Reuses `PersistenceController.open(storeURL:)`, HabitStore and scheduler;
no backup cloud integration, import feature, or new product schema is introduced by this task.

- [ ] Write `failureDoesNotReset` and `reopenStoreReconciles`: fail migration/open deliberately,
  check original store contents remain recoverable, then reopen normally. Restore a supported
  complete test store copy containing pending settings and reminder state; reconcile from DB.
  ```swift
  #expect(afterFailedOpen.originalFixtureDigest == beforeOpen.originalFixtureDigest)
  #expect(afterFailedOpen.replacementStoreCreated == false)
  #expect(restored.inventory == saved.inventory)
  #expect(restoredQueue.ids == expectedQueue.ids)
  ```
  Keep filesystem comparison at logical persisted-value level where SQLite may legitimately
  update file metadata. Include committed WAL data, notices, nil timestamps, operation receipts.
- [ ] Run `MigrationTests` and `RestoreTests`; confirm any missing safeguards fail the tests.
- [ ] Implement only needed non-destructive open/retry/error handling. Validate actual bundle
  model discovery, backup eligibility, and protected-data recovery; never delete store to recover.
- [ ] Re-run both suites. Perform D6's Apple backup restore and direct-transfer checks only with
  suitable devices and consent. Record blocked equipment/authorization rather than fake evidence;
  do not reset the owner's phone as an implicit part of development.
- [ ] Commit: `Verify migrations and local data continuity`.

## T11 — Offline and accessible version-one acceptance

**Files:** Create `HabitTrackerUITests/OfflineFlowTests.swift`, `AccessibilityFlowTests.swift`;
update affected UI/resources, `docs/testing/results/<date>-<build>.md`, and the matrix's evidence links.

**Interfaces:** Existing UI/services only. No new product feature or distribution work.

- [ ] Write `fullJourney` and `primaryControls`: cold launch, create, log, correct, report,
  configure reminders, read guide, export, cancel deletion, restart. Assert count/history/target
  values at each transition and named accessible controls; no sign-in/network prompt exists.
- [ ] Run UI convention commands with each suite; confirm failures are meaningful before fixes.
- [ ] Fix only observed integration/accessibility defects. Review bundle capabilities,
  dependencies and required-reason APIs; add accurate privacy manifest declarations only where
  required. Inspect target warnings, force unwraps/error paths and no destructive reset fallback.
- [ ] Run the full app's automated suite once for this integration gate, then D1/D4 and any
  remaining D2/D3/D5/D6 evidence. Check actual offline behavior, VoiceOver, largest Dynamic Type,
  light/dark and non-color progress. Reconcile every AC row to passed/failed/blocked evidence.
- [ ] Commit: `Validate offline and accessible habit tracker flows`.

## Plan review and handoff

The plan maps every SPEC §13 criterion to a task and concrete test in the acceptance matrix.
The added review-focus tests cover retry/crash, empty history, temporal rollback, concurrent
scheduling, and failed migration. The proposed data-model/type names above are shared by later
tasks; no implementation result is implied by a listed path, assertion, or command.

Review the Core Data decision and stage gates before authorizing code. Two execution choices:

- **Native:** one implementer works through these dependent tasks, then an independent whole-
  branch review. Recommended here because the shared date/store interfaces make serial work
  straightforward, with an early physical-device gate and focused tests throughout.
- **Subagent-driven:** a fresh implementer and reviewer for each task, plus a whole-branch review;
  more independent review along the way, with additional context and review overhead.

Whichever is selected, retain the stage A phone gate and do not treat App Store launch as part
of this plan. The owner has requested planning first; implementation awaits a subsequent request.
