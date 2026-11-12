# Integration verification

The full iOS 27.2 simulator suite passed 54 domain tests and six UI tests in
`.build-evidence/t11-full-suite.log`. This run preceded the independent review fixes.
After both fixes, `.build-evidence/t11-reviewed-suite.log` passed 56 domain tests and six
UI tests with exit zero. The focused report/intent run passed ten tests. No additional
independent re-review was performed after the regression fixes.
No app-owned network clients or third-party package dependencies were found in the source
and Xcode project inspection. Actual airplane-mode acceptance remains a physical D1 check.

OfflineFlowTests.testFullJourney exercises cold launch, create, log, correction to date-only,
reports, reminder settings, shortcut guide, export and share dismissal, cancelled deletion,
and relaunch preserving the completion and correction. AccessibilityFlowTests.testPrimaryControls
runs the description, clipping and Dynamic Type audits at the largest accessibility text size
on empty/populated activity lists and activity detail. The original audit failed on two
labels. The activity list now provides vertical text expansion and an accessibility-size
vertical layout for activity navigation/logging. The unchanged audit passes after those fixes.

The audit was subsequently expanded to all supported audit types, including contrast and
hit-region checks, on these same three primary screens. Its first run terminated with
"Test crashed with signal term" in the result bundle, without an accessibility finding.
An unchanged retry passed with exit zero in `.build-evidence/t11-accessibility-all-retry.log`.
The original terminated run remains in `t11-accessibility-all.log`. This establishes the
automated checks on those screens, while VoiceOver, light/dark review and accessibility of
every screen still require physical D4 evidence.
The full run also includes history, shortcut guide and export sharing UI tests.

The independent review identified two Important defects that the first passing suite missed.
See [review findings and fixes](2026-11-12-independent-review.md). The first individual-method filter for the
new Swift Testing report regression selected zero tests, so it was rerun at suite scope.

The owner connected `wall` on iOS 26.6.2. The signed device build succeeded and installed
using existing project signing settings. Launch was denied with a code-signature/entitlement/
profile-trust error. The owner was asked to check developer trust in iPhone Settings.
Subsequent devicectl process inspection found the installed HabitTracker executable running
on the phone. The owner was asked to execute the first create/app-log/Home-Screen-log/
correct/relaunch milestone. No tracking acceptance is claimed until those results arrive.
Read-only inspection of a copied app database subsequently found four activities and three
completions with source `shortcut`, with zero corrected entries and no app-origin completions.
SQLite integrity_check returned `ok`. This provides device persistence evidence for the
shortcut action, while it cannot identify whether the action was invoked from a Home Screen
icon, prove correction/relaunch behavior, or substitute for the remaining milestone steps.
The copy is local ignored build evidence and is not an Apple backup restoration test.
Device D1–D6 checks remain open, including backup
restoration and direct transfer with suitable equipment and explicit authorization.
