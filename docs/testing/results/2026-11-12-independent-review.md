# Independent implementation review

Read-only whole-app review against SPEC, architecture and the implementation plan completed
on November 12. The reviewer inspected domain, persistence, UI, reports, reminders,
notifications, export, shortcuts and tests. No Critical findings were reported.

Two Important findings were fixed and their focused regression suites passed ten tests.
The final whole-suite rerun passed 56 domain tests and six UI tests in
`.build-evidence/t11-reviewed-suite.log`. Physical acceptance remains open.

1. AppEnvironment.log, apply and retry catch a post-commit reload failure together with the
   mutation failure. A successful save can show a failed-save alert, encouraging a second
   log with a new operation ID. Preserve committed success and provide refresh retry feedback.
2. ReportCalculator.bounds for a week takes the first matching weekly period across all
   activities. During an extended week-start transition, a later-created habit can have a
   different initial period. Adding/deleting or reordering unrelated habits can change another
   habit's report range. Resolve boundaries from authoritative calendar rules/transitions.

Fix evidence is `.build-evidence/review-fixes-green.log`. The report regression first
reproduced two mismatches after reordering/removing unrelated weekly periods. Reports now
filter periods to the selected activity before resolving bounds. Weekly habits retain their
own persisted transition periods. Daily habits use the configured weekday clipped at the
next calendar transition. This changes the regression's explicit daily range to November
16–18, while preserving its independence assertions. The initial November 9–18 expectation
had incorrectly borrowed the unrelated weekly activity's extended goal interval.

The post-commit regression injects a failing snapshot reader after saved logging, rename,
and replay. The initial test build failed for the missing injection interface. The completed
test verifies successful confirmation/return values, no failed-save alert, preserved single
completion, and a refresh-needed state. The list provides an explicit refresh action.

Deferred minor findings from the reviewer are retained for the owner's review.

- HistoryEditorView formats the occurrence instant in the current timezone but appends the
  capture timezone label. After travel, the displayed time and zone can disagree.
- Production callers discard notification reconciliation outcomes. Delivery failures have
  no visible status/retry feedback, although saved tracking data remains intact.

The review did not establish physical D1–D6 behavior, real notification delivery/capacity,
Apple restore/direct transfer, Shortcuts setup labels on iOS 26, physical VoiceOver usability,
or performance on the owner's phone. These remain required device evidence gates.

The owner's Xcode project file changed externally to include development signing settings.
That uncommitted change is preserved outside the implementation commits.
