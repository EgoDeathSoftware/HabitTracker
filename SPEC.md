# Habit Tracker — Product and Implementation Specification

Status: Version 1.0 — accepted specification. Product implementation has not started.
Date: 2026-11-10.
Platform: Native iPhone application using Swift and SwiftUI, iOS 26 or later.
Initial test device: owner's iPhone, reported as running iOS 26.6.2.

## 1. Purpose

Help a person build consistency by recording activities and measuring how closely they follow
their own plan. Normal logging takes one tap. Extra repetitions cannot compensate for missed
days. The initial release is for personal use; an App Store release is a later milestone.

Do not claim that a particular number of days guarantees habit formation.

## 2. Confirmed requirements

- Users create activities with names, icons, and frequency targets.
- Log from the app or an activity-specific Home Screen shortcut. Each tap records one
  occurrence now. Brief in-app success confirmation is preferred; background logging is acceptable.
- Provide in-app, step-by-step instructions for creating each activity's Home Screen shortcut.
  The user completes setup in Apple's Shortcuts interface; automatic icon installation is not required.
- Multiple daily completions are supported. Weekly targets count distinct days, freely chosen;
  users do not assign specific weekdays.
- Weeks start on Monday by default, configurable in settings.
- Add missed entries to past dates; edit and delete incorrect entries.
- Weekly, monthly, and yearly reports include target progress, goals met, trends, and calendars.
- Optional per-habit reminders automatically adapt to local completion history. Multiple daily
  sessions have separate reminder times. Each automatic change produces a small in-app note.
- Weekly target changes at or before the midpoint apply to this week; later changes apply next
  week. Daily target changes apply immediately. Completed periods retain their original targets.
- Export all activities for a selected date range to a local CSV file.
- Deleting an activity deletes all its history after confirmation. No archiving in version 1.
- Native Swift/SwiftUI is the accepted implementation approach.

## 3. Permanent privacy constraints

All app-owned data and computation stay on the device. No accounts, sign-ups, application
servers, cloud databases, synchronization, remote analytics, advertising SDKs, or external AI
services. Setup, logging, editing, statistics, reminder calculation, and export work offline.

Apple-managed device backups, including iCloud Backup, are allowed under the device owner's
control. Preserve normal backup/migration eligibility. Verify restoration and device transfer
during testing rather than promising untested behavior.

Export generates a local file and presents the iOS share/save interface. The user chooses its
destination. The app never authenticates with or calls Google Sheets or another cloud service.
Deleting app data does not delete previous exports or copies in old device backups.

## 4. Version 1 implementation defaults

These defaults complete the product decisions above and are adopted for version 1 following
specification review. They originated as engineering proposals; validate the learning thresholds
and platform behavior during implementation without silently changing the product requirements.

| Topic | Version 1 rule |
| --- | --- |
| Target forms | Either N completions every day or N distinct days per week; no combined daily/weekly plan. |
| Target bounds | Daily: 1–10 completions. Weekly: 1–7 distinct days. |
| Extra logs | Preserve raw activity; cap its goal contribution. |
| Manual entries | Date-only backfills are allowed; actual time is optional. Backfills and edited logs do not train reminders. |
| Tracking start | Initially creation date; earlier backfills extend tracking using the initial target. |
| Partial periods | Show progress; omit initial/transition partial periods from historical success rates. |
| Weekly report attribution | Assign a week to the month/year containing its final calendar day. |
| Reminder learning | Five qualifying days minimum; a 28-day window for daily habits and 56 days for weekly habits; gradual changes. |
| Reminder coverage | Finite schedule replenished during use; indefinite reminders without further app/shortcut use are not guaranteed. |
| Changing cadence | Daily/weekly cadence stays fixed in version 1; numeric targets are editable. |
| Appearance | Native controls, built-in symbols, light/dark appearance, accessible text sizes. |

## 5. Functional surfaces and scope

Provide an activity list with icons, names, current progress, and one-tap logging; create/edit
activity controls; activity detail with calendar and editable history; weekly/monthly/yearly
reports; settings for week start and export; Home Screen shortcut setup guidance; adjustment
notes; and confirmed activity deletion.

Exact navigation, layout, colors, and animation are builder choices. Empty states explain the
next action. Progress remains understandable without color. Use VoiceOver labels and Dynamic Type.

Excluded from version 1: interactive widgets, Apple Watch/Android apps, social features,
payments, streaks, fixed weekday schedules, timers, duration/distance/quantity tracking,
automatic activity detection, archiving, and CSV import. CSV is a report, not a backup format.

## 6. Activities and completion records

An activity has a stable identifier, required nonblank name, built-in icon, cadence, and target.
Names/icons are editable without changing identity. Duplicate names are allowed, but selectors
must distinguish the intended activity.

Each deliberate tap creates a separate completion. A rapid double tap creates two logs that
can be corrected. Retry safety uses a unique operation identifier generated once for each
invocation and reused for retries. Independent concurrent invocations must both persist.

Store each record's identity, assigned calendar date, occurrence timestamp when known, capture
timezone, creation timestamp, source, and operation identifier. Persist before showing success.
A write failure must not increment visible counts or show success.

Users may add, edit, and delete individual entries. Backfills may be date-only; do not invent
precise times. Reject future dates. If a backfill precedes tracking start, explain and extend
the tracking range to that date; newly included earlier periods use the initial target.
Later target history is unchanged.

Corrections recalculate all affected periods, reports, and pending reminders. Deleting an entry
does not delete the activity. A timestamp/date-edited record is excluded from reminder learning.

### Home Screen logging

Expose a parameterized App Intent to record one completion for an activity's stable identifier.
Renaming must not break a shortcut.

Default behavior: bring the app forward, record once, and show brief success with updated
progress. Rendering the confirmation must not log again. Do not automatically close the app.
A supported background invocation may log without an in-app confirmation; errors must not
masquerade as success.

Users add icons through Apple's Shortcuts interface and choose the Home Screen name/icon.
Do not promise programmatic icon placement. A stale shortcut for a deleted activity explains
that the activity is unavailable and never recreates it.

#### Required in-app setup guide

Each saved activity offers a discoverable “Home Screen shortcut” help entry. The guide names
that activity and is available again later, not only during onboarding. Its full instructions
are bundled with the app and readable offline; an external help link alone is insufficient.
Shortcut setup is optional and must not block ordinary in-app logging.

The guide must walk a first-time user through:

1. Opening Apple's Shortcuts app and creating a new shortcut.
2. Finding this app's “Log Activity” action and adding it. The displayed action name must
   match the shipped App Intent's name exactly.
3. Selecting the saved activity as a fixed parameter, rather than asking which activity to
   log every time. Explain how to distinguish activities with duplicate names.
4. Naming the shortcut and using Apple's “Add to Home Screen” flow to choose a recognizable
   Home Screen name/icon and finish adding it.
5. Tapping the new icon to record one completion at the current date/time and checking the
   updated activity history/progress. Explain that this is a real log; if used only as a
   setup test, the user can remove it through the history editor.

Explain that one tap means one occurrence: it meets a once-daily target, contributes one
distinct day toward a weekly target, and contributes one completion toward a multiple-daily
target. It must not imply that one tap always finishes the entire goal.

Include concise troubleshooting for a missing action/activity, an unconfigured activity
parameter, and a shortcut referencing a deleted activity. Tell users to save the activity
first, reselect the intended activity if necessary, and remove/recreate an obsolete shortcut.
Creating or reading the guide never records activity. Renaming an activity preserves the
shortcut's binding, but its user-chosen Home Screen label may need manual editing.

Verify the guide's actual navigation labels and steps on supported iOS 26 during implementation.
Validate that someone can complete setup using only this guide and Apple's system interfaces.

### Deletion

Confirmation names the activity and states that all recorded history will be removed.
Cancel changes nothing. Confirm atomically removes the activity, logs, target history, pending
target changes, and adjustment notices. Cancel its notifications, remove it from reports and
future exports, and reconcile again on next launch if notification cancellation is interrupted.

## 7. Targets and dates

### Daily

For target N and raw count C on a date:

- Credited completions = min(C, N).
- Progress = min(C, N) / N.
- Goal met when C is at least N.

Every calendar day is planned. A twice-daily target requires two completions each day.
Surplus completions never carry to another date.

### Weekly

Target N means activity on N distinct dates in a week. For D active dates:

- Credited days = min(D, N).
- Progress = min(D, N) / N.
- Goal met when D is at least N.

Multiple logs on one date earn one day of credit. All dates are freely chosen.

### Calendar behavior

Use the Gregorian calendar. Weeks start at local midnight on the configured weekday; default
is Monday 00:00 through next Monday 00:00, end exclusive.

Assign live logs the local date/timezone at capture. Preserve that date when travelling;
do not regroup old records merely because the device timezone changes. Reminders use local
wall-clock times, reconciled after observed timezone/clock changes. For a DST gap use the next
valid time; for a repeated local time schedule once.

Creation after a period has started makes that initial day/week partial. It shows progress but
is excluded from completed-period success rates. An earlier-date backfill extends tracking to
midnight on that date; this can make previously partial periods eligible. Deleting the earliest
log does not automatically shorten the tracking range or erase intervening missed periods.

Week-start edit behavior: display an effective date at the next occurrence of the new
weekday. End the current weekly period there, marking it transitional if it is not a normal
seven-day period; exclude it from historical success rates. Preserve earlier period boundaries.
Daily habits are unaffected. A second edit before activation replaces the pending setting.

## 8. Target changes

Daily numeric changes re-evaluate the entire current day immediately, retaining logs.
Earlier days keep their targets.

For normal weeks, midpoint means three calendar days and 12 hours after the start:
Monday start gives Thursday noon. At the exact midpoint a change applies immediately.
For a transitional period use the midpoint between its local start and end.

| When changed | Behavior |
| --- | --- |
| At/before midpoint | Replace this week's target and re-evaluate its existing logs. |
| After midpoint | Keep this week's target; activate the replacement next week. |

Show current/pending targets and the effective date. A later edit replaces the pending value;
saving the current target cancels the pending change. If week-start settings change, move the
pending target to the resulting next boundary.

Effective targets are determined from dates even when the app was closed at the boundary.
Past targets stay fixed; correcting past logs still changes past progress. Target increases
can reduce current adherence; decreases can satisfy a goal. Reconcile reminder eligibility
and daily reminder slot counts after an effective change.

Exceptional clock/timezone rollback: once a period has closed in stored history, its target
and boundaries do not reopen merely because the local clock returns to that date/week.
History correction remains allowed. Target edits in this situation take effect in the first
not-yet-closed period, with its effective date shown. Do not create a second copy of a period.
This exception preserves historical targets over the ordinary immediate-edit rule.

## 9. Reports

Report per activity; no combined cross-habit score is required.

| Measure | Definition |
| --- | --- |
| Target progress | Credited units divided by the applicable target. |
| Goals met | X of Y eligible completed days for daily habits; X of Y weeks for weekly habits. |
| Trend | Adherence compared with the prior equivalent completed report period; changes in percentage points. |
| Calendar | Dates/counts, including partial/met daily status. Unlogged dates of weekly habits are not individually failures. |

Historical adherence = sum of credited units across eligible completed periods / sum of their
targets × 100. Use each period's own target. Round only display values to whole percentages;
never average rounded percentages or exceed 100%. No eligible history means “Not enough history.”

- Weekly reports show each habit, target progress, and what remains. For daily habits, keep
  today's progress separate from completed-day adherence. An open weekly goal is in progress.
- Monthly reports include daily goals on that month's dates and weekly goals whose final
  calendar day is in that month; include a weekly breakdown and prior-month comparison.
- Yearly reports use the corresponding year rule and a monthly breakdown.

A week ending Sunday December 6 belongs to December's weekly-goal summary even if it begins
in November. Label its complete dates. Calendar entries remain on their actual dates.
Do not split, prorate, or double-count weekly goals between months/years.

Open days/weeks and initial/transition partial periods are not failures. Show them separately.
Current-month/year summaries include completed eligible periods so far. Do not compare them
with a full prior month/year; instead show the last two completed months/years, explicitly
labelled, or unavailable if insufficient history. Raw counts may be shown alongside goal credit.

## 10. Adaptive reminders

### Setup and suppression

Reminders are optional per habit and initially off. Request notification permission on first
enablement. Denial leaves tracking usable and provides a route to system settings.

Weekly habits have one initial time. Daily habits have one per required completion. Users
choose these seed times, at least 30 minutes apart. Increasing a daily target requires seed
times for added slots when reminders are enabled; decreasing it retains the earliest slots.

Weekly reminders are eligible while the target is unmet and today has no completion.
A completion suppresses further nudges that day; meeting the target suppresses the rest of
the week. Daily reminders stop once the day's target is met. Each completion satisfies one
slot in chronological order. Never replay elapsed reminders in a burst; corrections can
restore future eligible reminders only. Disabling reminders cancels pending requests.

Use gentle wording such as “A moment for reading?” The app knows what was logged, not what
actually happened. Tapping a notification opens the activity; it does not log automatically.

### Initial local learning algorithm

Recalculate after relevant activity changes and when the app becomes active.

1. Use the previous 28 completed local calendar days for daily habits and 56 for weekly habits,
   allowing a once-weekly habit to collect five samples. Eligible samples are live, unedited,
   timestamped app/shortcut logs. Exclude manual backfills and edited records.
2. Weekly habits: use the first eligible completion on each active date.
3. Daily habits: use dates with at least N eligible logs for the current target N, sorting the
   first N by occurrence time and assigning them to N chronological slots. Ignore surplus logs.
4. Require five qualifying dates under the current target configuration. A target change
   begins a new learning window; retained reminder times become the seeds.
5. Estimate each slot with the circular median of local times, handling midnight. Break ties
   in favor of the estimate closest to the existing time.
6. Round to five-minute increments. Change only for a difference of at least 15 minutes;
   move at most 30 minutes per local day. Reopening repeatedly must not bypass the limit.
   Retain a slot's time if the proposed move reorders slots or reduces spacing below 30 minutes.
7. Persist the habit, old/new times, and reason for every applied change. Display a small note
   at the next app opportunity until acknowledged. Group one calculation's multiple-slot
   changes into one note; no extra notification is required.

Do not learn mandatory weekdays. These thresholds are initial defaults to validate.

### Scheduling and platform limits

Use local notifications only. The database is authoritative; the notification queue is derived.
Reconcile after logging, corrections, target/settings changes, deletion, app activation, and
any background refresh granted by iOS.

Queue policy: generate eligible times for the next 28 days, sort with stable tie-breaking,
and schedule the earliest 60 requests. This is a conservative application budget to validate
on the supported OS, not a guarantee of OS capacity. Use stable identifiers, check scheduling
errors and pending requests, and remove stale notifications. A scheduling failure never
rolls back an already saved completion.

iOS delivers scheduled notifications while the app is closed, subject to permissions, Focus,
system settings, and OS scheduling. Background execution is not guaranteed. The finite queue
can run out if there is no app or shortcut use; more reminder slots shorten its coverage.
Opening/logging replenishes it. Background refresh is assistance, not a correctness dependency.
Do not promise unlimited unattended reminders or exact-to-the-minute delivery.
Finite reminder coverage is an accepted version 1 tradeoff and must be explained accurately.

## 11. CSV export

Select inclusive start/end dates; reject an inverted range or an end date after today.
Include every stored activity whose tracking range intersects the selection. Produce CSV with a row for
each activity/date within that range, including zero-count dates. Encode the file as UTF-8.

| Columns | Meaning |
| --- | --- |
| activity_id, activity_name | Stable identity and current name. |
| date | Assigned local date, YYYY-MM-DD. |
| cadence, target | Daily/weekly and the target for the containing period. |
| period_start, period_end_exclusive | Target period boundaries. |
| raw_count | Number of retained completions on this date. |
| daily_credited_completions | min(raw_count, target) for daily habits; empty for weekly. |
| weekly_active_day | 0 or 1 for weekly habits; empty for daily. |
| period_status | complete, in_progress, initial_partial, or transitional. |

Weekly active days are uncapped observations; a consumer groups by period and caps their sum
at the target. Keep the headers unambiguous. Escape separators, quotes, and line breaks.
Neutralize formula-like user text in exported cells without changing stored values.

Cancelled export changes nothing. A range with no rows explains that result. Release temporary
files after sharing completes. No timestamps are invented for date-only entries, and this
daily-summary export does not claim to preserve every detail needed to restore the app.

## 12. Persistence and architecture

Use a transactional local database with schema migrations. SwiftData, Core Data, or SQLite is
a builder choice based on reliable App Intent access and migration support. No cloud container
or external service may be required. This spec requires no third-party dependency.

Persist activities, completions/operation IDs, target and period history, pending target changes,
reminder configuration/effective times/learning-window boundaries, adjustment notices, and
week-start settings/transitions. Period history must reconstruct targets even for dates with
zero completions; deriving planned periods only from logs is incorrect.

Logs are the source of counts. Invalidate any cached reports after relevant changes.
Commit logging, corrections, target edits, and deletion atomically. Reconcile notifications
after database commit and retry safely. Use normal iOS file data protection.

Separate goal calculations, persistence, learning, and scheduling from views. App and App Intent
share the same rules. Inject clock/calendar into calculations so boundary behavior is testable.
No network connection is required to launch or use the app.

## 13. Acceptance criteria

| ID | Scenario and expected result |
| --- | --- |
| AC-01 | Setup, log, correct history, view reports, calculate reminders, and export in airplane mode without an account. |
| AC-02 | Daily target 1 with two logs: raw 2, credited 1, progress 100%. Daily target 2 with one log: 50%; a third log cannot exceed 100%. |
| AC-03 | Weekly target 2: two Monday logs earn one day; a Tuesday log meets the goal. |
| AC-04 | Monday-start target edit Thursday at noon affects this week; one second later affects next week. Prior targets stay fixed. |
| AC-05 | Later pending-target edit replaces the value; saving the current target cancels it. Correct activation on reopening requires no background execution. |
| AC-06 | Backfill/move/delete updates affected reports and future reminders. Date-only entries retain unknown time and do not train reminders. |
| AC-07 | Shortcut saves once and confirms after commit. Retry of its operation ID adds nothing. Independent simultaneous logs are retained. |
| AC-08 | Renaming preserves shortcut identity. Deleted-activity shortcut fails clearly and never recreates data. |
| AC-09 | Cancelling activity deletion preserves data. Confirming removes its data, reports, notices, and pending reminders. |
| AC-10 | Weekly reminders stop after today's completion and for the rest of a fulfilled week. Daily reminders stop when the daily target is met. |
| AC-11 | Multiple daily reminder slots learn separately. Fewer than five eligible dates preserves seeds; adjustments obey thresholds and show old/new-time notes. |
| AC-12 | Open/partial periods are not failures. No completed history shows insufficient history. Capped adherence never exceeds 100%. |
| AC-13 | A cross-month/year week is attributed exactly once by its final date; raw calendar/CSV dates are unchanged. |
| AC-14 | Test midnight, leap day, custom week start, timezone travel, DST gap/repeat, and pending week-start transition. No silent movement of historical log dates. |
| AC-15 | CSV includes zero dates/historical targets and safely handles names with quotes, commas, newlines, and formula prefixes. |
| AC-16 | Permission denial, scheduling failure, queue capacity/exhaustion do not block logging; rebuilding the queue creates no duplicates. |
| AC-17 | Failed database write shows no increment/success. Notification failure after a saved log does not erase that log. |
| AC-18 | Schema migration, backup restoration, and direct phone transfer preserve data/settings/pending changes. Reconcile reminders after restore. |
| AC-19 | Primary flows work with VoiceOver, large Dynamic Type, light/dark mode, and accessible icon labels. |
| AC-20 | Travel/clock rollback into an already closed period preserves its target. A target edit affects the first unclosed period; existing history remains correctable. |
| AC-21 | A first-time user follows the in-app guide to create a named activity-specific Home Screen icon. One tap logs once without asking which activity, with correct daily/weekly goal credit. |
| AC-22 | The setup guide is accessible per activity, available offline and repeatable. Setup alone creates no logs; a real test log can be removed. In-app tracking works without shortcut setup. |

Unit-test goal calculations, target/period rules, learning, and export; integration-test
persistence and intents. Validate actual shortcut setup, background notification behavior,
backup/migration, and accessibility on a physical iPhone, not solely in a simulator.

## 14. Approaches and handoff

Selected: native Swift/SwiftUI with local persistence and App Intents, accepted by the owner.
It directly fits the iPhone-first scope and Apple integrations.

Considered: cross-platform framework. This could support Android, but that is outside scope
and the iOS features still need platform-specific integration. No current requirement justifies it.

The original Sheets-backed tracker was replaced by this app. Sheets may consume a user-exported
file but is never a storage dependency.

Use section 4's defaults, including notification coverage, learning, report attribution, and
fixed cadence. Database framework, internal APIs, navigation/layout, symbol palette, and test
framework remain builder choices to resolve in the implementation plan.

The deliverable for this task is this specification. Start product implementation only after a
subsequent explicit request. No product code, scaffolding, dependencies, or deployment is part
of the specification task. A public App Store release needs a later distribution, metadata,
privacy-disclosure, and release-readiness pass.

## 15. Platform references

- [Apple: Home Screen shortcuts](https://support.apple.com/guide/shortcuts/add-a-shortcut-to-the-home-screen-apd735880972/ios)
- [Apple: App Intent runtime behavior](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents)
- [Apple: Local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)
- [Apple: Notification delivery and cancellation](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/RemoteNotificationsPG/SchedulingandHandlingLocalNotifications.html)
- [Apple: Background execution principles](https://developer.apple.com/videos/play/wwdc2025/227/)
- [Apple: Quick Start transfer](https://support.apple.com/en-us/102659)
- [Apple: Backup methods](https://support.apple.com/en-us/108771)
- [Apple: What iCloud backs up](https://support.apple.com/en-us/108770)
