# Acceptance tests and evidence

Updated November 12, 2026. Implementation and automated verification are in progress.
The original test-design table below records planned coverage. Actual test names and
results are recorded in the dated evidence files under `results/`. Physical procedures
D1–D6 remain unverified, so version-one acceptance remains open.
Sources: [SPEC.md](../../SPEC.md), [architecture](../architecture/0001-local-storage-and-domain.md),
and [implementation tasks](../superpowers/plans/2026-11-10-habit-tracker.md).

U = deterministic unit test; I = integration test against a temporary on-disk SQLite store;
UI = XCUITest; D = physical iPhone procedure. Unit tests use an injected clock/timezone and
Gregorian calendar. Tests must not sleep until real midnight or rely on internet access.

## All 22 acceptance criteria

| Criterion | Automated evidence to implement | Physical evidence / exact expected result | Owner task |
| --- | --- | --- | --- |
| AC-01 | `OfflineFlowTests/fullJourney` (UI): create, log, edit history, report, reminder calculation, export; no account surface. | D1: same journey with airplane mode and Wi-Fi off; zero app-owned network dependencies. | T03–T09, T11 |
| AC-02 | `GoalRulesTests/dailyCredit`: target 1/raw 2→credit 1; target 2/raw 1→50%; target 2/raw 3→100%. | D1: same counts visible in list/detail/report. | T01, T04, T06 |
| AC-03 | `GoalRulesTests/weeklyDistinctDays`: two Monday logs→1/2; add Tuesday→2/2. | D2: Home Screen tap uses identical credit rules. | T01, T05 |
| AC-04 | `PeriodRulesTests/weeklyMidpoint`: 2026-11-12 12:00:00 changes Nov 9–16; 12:00:01 stages Nov 16. Closed targets unchanged. | Target editor shows correct effective date before save. | T02, T04 |
| AC-05 | `PeriodRulesTests/pendingReplacementAndActivation`: replace 4 with 5, save current 2 to cancel; reopen after two boundaries activates once without background work. | D1: kill/reopen with pending change represented correctly. | T02–T04 |
| AC-06 | `HistoryTests/correctionsRecalculate`: backfill/move/delete affects both dates/periods; date-only has nil time; edited/manual samples excluded. `NotificationPlannerTests/correctionRestoresFutureOnly`. | D1: earlier backfill warns, extends tracking, test log removable. | T04, T07, T08 |
| AC-07 | `HabitStoreTests/retryAndConcurrency`: same operation twice→one; distinct simultaneous IDs→two; reused ID/different payload→error. `IntentTests/confirmationAfterSave`. | D2: one Home Screen tap adds one; rendering confirmation adds none; rapid double tap adds two. | T03, T05 |
| AC-08 | `IntentTests/identitySurvivesRenameAndDeletion`: same UUID resolves after rename; deletion produces unavailable error and no records. | D2: existing shortcut works after rename; stale shortcut fails clearly. | T04, T05 |
| AC-09 | `HistoryFlowTests/deleteCancelAndConfirm` (UI), `HistoryTests/cascadeDelete` (I), `SchedulerTests/deletedActivityReconciliation`. | D1/D3: cancel retains everything; confirm removes history, reports, notes, notifications. Other habits unaffected. | T04, T08 |
| AC-10 | `NotificationPlannerTests/suppression`: weekly target 2, one log today→no more today; two active dates→none this week. Daily target 2 with both seed times still ahead, counts 0/1/2→2/1/0 future slots. | D3: log before due time; cancelled nudge absent where OS cancellation completes. | T08 |
| AC-11 | `ReminderLearningTests/slotsThresholdsAndNotices`: four qualifying dates→unchanged; five→slot-specific change; exclude backfills/edits; 28/56-day windows; 15-minute threshold, 30-minute/day cap and spacing. | D3: adjustment note displays old/new times, survives restart, disappears only after acknowledgment. | T07 |
| AC-12 | `ReportTests/eligiblePeriodsAndWeightedRate`: none→insufficient history; open/partial excluded; credits 1+2, targets 1+3→75%, not average of individual rates; surplus cannot exceed 100%. | D4: labels distinguish in-progress from missed/completed. | T01, T06 |
| AC-13 | `ReportTests/crossMonthAndYear`: Nov 30–Dec 7, 2026 belongs only to December; Dec 28, 2026–Jan 4, 2027 only to 2027. `CSVExportTests/assignedDatesRemain`. | D4/D5: calendar/CSV preserve November/December observation dates. | T06, T09 |
| AC-14 | `PeriodRulesTests/calendarEdges`: midnight, 2028-02-29, Sunday-start replacement. `HistoryTests/travelKeepsAssignedDay`; `NotificationPlannerTests/dstOnce`: New York 2026-03-08 02:30→03:00; 2026-11-01 01:30→one request. | D3: supported phone timezone change reconciles future notifications without moving old logs. | T01, T02, T04, T08 |
| AC-15 | `CSVExportTests/rangeAndEscaping`: inclusive dates, zero rows for missing days, historical targets, commas/quotes/newlines, prefixes = + - @ and leading whitespace/control characters. | D5: file opens with literal names in a spreadsheet; user may manually import to Sheets. | T09 |
| AC-16 | `SchedulerTests/deniedFailureCapacityAndReplay`: deny permission, fail add, >60 candidates, horizon expiry, rebuild twice→no duplicate IDs; stable earliest 60 over 28 days. | D3: denial leaves tracking usable; close app for delivery; queue coverage limitation visible. | T08 |
| AC-17 | `HabitStoreTests/saveFailureIsAtomic`; `IntentTests/noSuccessOnSaveFailure`; `SchedulerTests/failureKeepsSavedLog`. | D1: actionable storage error, no false increment; notification failure does not erase saved history. | T03, T05, T08 |
| AC-18 | `MigrationTests/v1ToV2PreservesData` (I), `MigrationTests/failureDoesNotReset`, `RestoreTests/reopenStoreReconciles` (I). | D6: Apple backup restore and direct phone transfer separately preserve all fixture values and reconcile reminders. **Requires real restore/transfer equipment and explicit authorization for those device operations.** | T07, T10 |
| AC-19 | `AccessibilityFlowTests/primaryControls` (UI): identifiers/labels and large-type navigation; automated checks where supported. | D4: manually complete flows with VoiceOver, largest accessibility size, light/dark; progress readable without color. | T03–T09, T11 |
| AC-20 | `PeriodRulesTests/closedPeriodRollback`: close Nov 9, return to Nov 9, target edit applies first unclosed period; correction still changes Nov 9 counts. No duplicate periods. | D1: effective-date explanation shown for rollback case using test clock in test build. | T02, T04 |
| AC-21 | `IntentTests/fixedActivityParameter`; `ShortcutGuideTests/oneOccurrenceCopy` (UI). | D2: first-time user follows bundled guide on supported iOS 26; fixed activity, chosen icon/name, no activity prompt on tap; correct 1/day, 2/day, 2/week behavior. | T05 |
| AC-22 | `ShortcutGuideTests/repeatableOfflineAndNoSideEffects` (UI): access per saved habit; reopen offline; no log on guide/setup; history can delete real test log. | D2: ordinary in-app logging works without creating any shortcut. | T04, T05, T11 |

## Implemented evidence

The following inventory maps the acceptance criteria to implemented checks. The full
pre-review run passed 54 domain and six UI tests. The post-review run passed 56 domain and
six UI tests. Final post-review integration is recorded in the
[integration results](results/2026-11-12-integration.md). Every required physical check
remains open, so these automated results do not establish full acceptance of any device gate.

| Criterion | Implemented automated evidence | Remaining verification |
| --- | --- | --- |
| AC-01 | OfflineFlowTests.testFullJourney, plus domain/export suites | D1 airplane mode on phone |
| AC-02 | GoalRulesTests.dailyCredit, HistoryFlowTests | D1 display comparison |
| AC-03 | GoalRulesTests.weeklyDistinctDays | D2 shortcut taps |
| AC-04 | PeriodRulesTests.weeklyMidpoint | Phone effective-date preview |
| AC-05 | PeriodRulesTests.pendingReplacementAndActivation, MigrationTests | D1 pending state after relaunch |
| AC-06 | HistoryTests.correctionsRecalculateTravelKeepsAssignedDayAndCascadeDelete, NotificationPlannerTests | D1 backfill and correction flow |
| AC-07 | HabitStoreTests.retryAndConcurrency, IntentTests.confirmationAfterSave | D2 rapid real shortcut taps |
| AC-08 | IntentTests.fixedActivityParameterSurvivesRenameAndDeletion | D2 saved shortcut identity |
| AC-09 | HistoryFlowTests.testCreateLogRestartAndDelete, HistoryTests, SchedulerTests.latestRevisionWins | D1/D3 OS cancellation |
| AC-10 | NotificationPlannerTests.capacitySuppressionAndCorrection, weeklySuppressionAndFutureOnly | D3 delivery suppression |
| AC-11 | ReminderLearningTests, MigrationTests notice persistence | D3 notice usability and real learning |
| AC-12 | ReportTests.eligiblePeriodsAndWeightedRate, completedPeriodComparisons | D4 report labels |
| AC-13 | ReportTests.crossMonthAndYear, CSVExportTests.assignedDatesAndHistoricalTargets | D4/D5 actual exported view |
| AC-14 | PeriodRulesTests.calendarEdges, HistoryTests, NotificationPlannerTests.dstOnce | D3 phone timezone changes |
| AC-15 | CSVExportTests, ExportFlowTests.testExportAndCancelSharing | D5 spreadsheet interpretation |
| AC-16 | SchedulerTests, NotificationPlannerTests capacity/expiry/order checks | D3 OS capacity and delivery |
| AC-17 | HabitStoreTests.saveFailureIsAtomic, IntentTests.noSuccessOnSaveFailure and committedChangesSurviveRefreshFailure, SchedulerTests.failureKeepsSavedLog | D1 physical storage failure UI |
| AC-18 | MigrationTests.v1ToV2PreservesData, RestoreTests.failureDoesNotReset and reopenStoreReconciles | D6 Apple restore and transfer |
| AC-19 | AccessibilityFlowTests.testPrimaryControls description/clipping/Dynamic Type audits | D4 VoiceOver, contrast, light/dark, all screens |
| AC-20 | PeriodRulesTests.closedPeriodRollback | D1 effective-date explanation |
| AC-21 | IntentTests.fixedActivityParameterSurvivesRenameAndDeletion, ShortcutGuideTests | D2 iOS 26 shortcut setup |
| AC-22 | ShortcutGuideTests.testRepeatableGuideExplainsOneOccurrenceWithoutLogging, OfflineFlowTests | D2 first-time setup and ordinary logging |

- Tracking, period rules, SQLite and shortcuts have focused results in
  [domain foundation](results/2026-11-10-domain-foundation.md),
  [local store](results/2026-11-10-local-store.md),
  [calendar/history](results/2026-11-10-calendar-history.md), and
  [in-app tracking](results/2026-11-10-in-app-tracking.md).
- Reporting and reminder learning have results in
  [reports](results/2026-11-10-reports.md) and
  [reminder learning](results/2026-11-10-reminder-learning.md).
- Notification queue policy and reconciliation have results in
  [notification planning](results/2026-11-12-notification-planner.md).
- CSV export and local continuity have results in
  [CSV export](results/2026-11-12-csv-export.md) and
  [data continuity](results/2026-11-12-data-continuity.md).

## Device procedures

Record device model, exact iOS version, app build/commit, date, steps, result, and evidence path
in `docs/testing/results/<date>-<build>.md` during execution. Use statuses **not run**, **passed**,
**failed**, or **blocked**. A simulator pass never substitutes for a required device result.

### D1 — Offline tracking and correction

1. Use a test installation; enable airplane mode and disable Wi-Fi. Launch from cold start.
2. Create Reading daily 2 and Exercise weekly 2; create a duplicate name with a different icon.
3. Log Reading three times: raw 3, credited 2. Exercise twice today: one credited day.
4. Add a date-only older entry before creation; accept the tracking-range explanation. Verify
   its unknown time, newly included zero dates, and retained history after deleting that entry.
5. Move/delete a completion, edit a target, cancel activity deletion, then confirm deletion
   of the duplicate. Reopen; exact retained records/settings match the expected values.
6. Finish report, reminder settings/learning, and CSV actions without network access. Storage
   failure/clock fixtures use a test-only injected dependency, not a user-facing debug setting.

### D2 — Actual Home Screen setup

1. Give a person unfamiliar with the app only its bundled guide and a saved activity.
2. Observe creation through Apple's current iOS 26 labels. Correct the bundled guide if it
   diverges; do not fill gaps verbally and then count setup as a pass.
3. Tap the icon from cold/warm app states; count exactly one new completion and confirmation
   after save. Repeat across daily 1, daily 2, and weekly 2 fixtures; no per-tap activity prompt.
4. Rename the activity, then use the existing icon. Delete it, then verify the stale icon's error.
5. Read/reopen guide offline without logging, and remove the real setup-test entry in history.
   Check duplicate-name disambiguation and missing/unconfigured/deleted-activity troubleshooting.

### D3 — Notifications and learning

1. Deny permission and verify logging; later enable via system settings and reconcile.
2. Choose near-future seed times with valid spacing. Verify a scheduled notification while
   the app is closed, then tap it: activity opens, count stays unchanged.
3. Exercise daily/weekly suppression, disable reminders, and delete the activity. Inspect the
   pending request inventory as well as observed delivery; Focus may affect visible delivery.
4. Populate qualifying live-history fixtures through a test build, apply learning, and verify
   old/new-time notes, restart persistence, acknowledgment, and repeated recalculation limits.
5. Change timezone, reconcile, and verify old assigned dates and replacement future requests.
6. Verify >60 candidates, expiry/no overdue burst, and finite-coverage explanatory copy.
   Automated injected-clock tests prove horizon exhaustion; don't wait 28 real days to do so.

### D4 — Reports and accessibility

1. Use known daily/weekly fixture histories with partial periods, zero dates, target changes,
   and cross-month/year weeks. Compare all totals against the matrix's exact expected results.
2. Confirm current summaries and comparisons name the periods they include; an unfinished
   month is not compared with a full prior month. Weekly blank dates are not labelled failures.
3. With VoiceOver, create/log/correct, inspect reports, configure reminders, find the shortcut
   guide, export, and cancel deletion. Repeat navigation at the largest Dynamic Type setting.
4. Check clipped text, focus order, control names, non-color status cues, and both appearances.

### D5 — CSV interoperability

Export a three-day fixture containing zeros, target changes, duplicate names, Unicode, commas,
quotes, embedded newlines, and formula-like names. Compare parsed values with expected rows;
open in a spreadsheet and confirm names remain literal. Cancel a second export and verify no
data changes. Complete sharing and verify temporary cleanup; interrupt and verify launch cleanup.
The app itself never connects to Sheets. Empty and invalid ranges produce clear feedback.

### D6 — Migration, restore, and transfer

Use a fixture inventory with IDs, raw counts, assigned dates, historical/pending targets,
week-start transition, seed/effective reminder times, and unacknowledged notes. First test the
internal V1→V2 store upgrade without loss. Separately test an Apple-managed backup restoration
and Quick Start/direct transfer with consent and suitable devices; compare every fixture value,
then launch and verify reminder reconciliation and current notification permission handling.
If spare devices or a restorable backup are unavailable, mark those checks blocked. Do not
claim AC-18 fully passed or erase/reset the user's phone to complete a checklist.

## Additional failure cases assigned to tasks

| Case | Planned test and owner |
| --- | --- |
| Crash after save before success, retry after manual deletion | `HabitStoreTests/replayAfterRestartOrDeletion`, T03/T04: no duplicate or resurrection. |
| Months without launch and zero completions | `PeriodRulesTests/materializeEmptyGap`, T02: targets exist for every planned period. |
| Notification reconciliation overlaps a new log/deletion | `SchedulerTests/latestRevisionWins`, T08: final OS queue matches newest committed state. |
| Model/store open failure or protected data unavailable | `MigrationTests/failureDoesNotReset`, T10; `HabitStoreTests/protectedStoreUnavailable`, T03: preserve data and show retry state. |
| Long history/export work on UI thread | T06/T09: ten years × 25 daily habits fixture; cancellable export, no work performed on main actor beyond rendering/share presentation. Record measured timings; no invented latency SLA. |

## Completion policy

Each task records its focused automated results and any device evidence it owns. Before calling
version 1 accepted, all AC rows need their required evidence. Personal milestone use may begin
earlier with explicitly listed outstanding checks. App Store submission is a separate task and
does not follow automatically from this plan. Automated results are linked above.
