# In-app tracking — November 10, 2026

T04 app surfaces: activity creation and name/icon edits, one-tap logging, stored progress,
target changes and preview, week-start settings, date-only or timed entries, individual entry
correction/deletion, confirmed activity deletion, and a recoverable local-store error state.
The shared action path retains failed log requests for explicit retry with their original IDs.

Full simulator run succeeded with 22 domain/store tests and two UI tests.
`.build-evidence/t04-suite.log` records the command result and xcresult.
`HistoryFlowTests` created an activity, logged, cold relaunched the app, verified persisted
progress, then checked both cancel and confirm activity deletion. `HistoryTests` checked
travel preservation, date-only correction across a week boundary, and activity-scoped deletion.

Remaining checks: physical iOS 26 installation, accessibility and end-to-end correction/shortcut
setup. Separate UI checks for invalid future dates and save-error presentation are not run.
