# Notification planner progress

T08 is in progress. The pure planner projects reminder configuration and goal periods
through 28 local calendar dates, suppresses satisfied goals and credited slots, and selects
the earliest 60 requests with stable ordering and timezone-sensitive identifiers.

The focused simulator run on iPhone 18 Pro, iOS 27.2 passed two tests on November 12.
Coverage includes capacity, unique and stable IDs, daily suppression, correction restoration,
disabled reminders, the New York spring gap at 02:30 moving to 03:00, and scheduling only
the first repeated 01:30 in autumn. The initial run failed because NotificationPlanner did
not exist. Logs are in `.build-evidence/t08-planner-red.log` and
`.build-evidence/t08-planner-green.log`. No compiler warnings appeared in the final log.

The notification client, OS adapter, permission request, lifecycle and mutation hooks,
and notification navigation are implemented. A coalescing scheduler reconciles stale IDs,
refreshes matching request content, and retries a newer revision after an in-flight add.
Two scheduler tests pass for denial, stale removal, replay and suspended-add deletion.
Scheduling runs after the store commits. Notification taps navigate without logging.

The full simulator run in `.build-evidence/t08-suite.log` passed 40 domain tests and
three UI tests, including handling the OS permission prompt and preserving reminder settings
across relaunch. The UI test target emits Apple's metadata-extraction warning because that
target has no AppIntents dependency. The focused projection run subsequently passed four
planner tests, adding weekly suppression, future-only correction restoration, timezone
replacement, expiry, and weekly pending-target activation. The new failure test proves that
an add error cannot invalidate a committed log or turn a replay into another completion.

An initial pending-target fixture incorrectly expected daily targets to defer. Existing
PeriodRules and the specification apply daily edits immediately. The fixture now uses a
weekly target edited after midweek and verifies activation on Monday.

The final domain run passed 44 tests, including permission-request errors, 20 concurrent
reconciliation callers, and notification navigation that preserves completion count.
The subsequent five-test planner run passed stable UUID ordering across three habits and a
pending week-start transition. Logs are `t08-final-domain.log` and `t08-ordering.log`.

Physical-device D3 delivery, Focus behavior, OS queue capacity, and supported-iOS-26 checks
remain unverified. Simulator queue-policy tests establish application behavior only.
