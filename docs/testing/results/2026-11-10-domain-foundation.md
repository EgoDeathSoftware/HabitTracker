# Domain foundation — 2026-11-10

Implementation authorized by the owner on November 10. This is an initial T01 slice,
not completion of Stage A or the phone milestone.

## Implemented

- Native Xcode project with app, hosted Swift Testing, and XCUITest targets and shared scheme.
- iOS 26 deployment target, Swift 6, complete strict concurrency checking.
- Empty SwiftUI launch host; no activity management or storage yet.
- Validated Gregorian dates, inclusive date ranges, captured clock readings, habit drafts,
  completion/goal snapshots, and pure daily/weekly goal credit rules.
- Apple frameworks only; no dependencies or cloud capabilities.

Activity snapshots and command contracts will be added with their first consumers in T02–T03.
Period snapshots currently expose an inclusive calculation range; T02 must add the persisted
end-exclusive boundary, historical target metadata, and eligibility fields from the design.

## Actual verification

Toolchain: Xcode 27.2 (27B52). Simulator: iPhone 18 Pro, iOS 27.2,
`F218A46D-1C67-488A-A5AD-DE46317FD22B`.

Initial red run failed compilation because Cadence, CalendarDay, DayRange, and snapshot types
were absent. After implementation, two missing `try` expressions in tests were corrected.

Final command (exit 0, `TEST SUCCEEDED`):

```sh
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project HabitTracker.xcodeproj -scheme HabitTracker \
  -destination 'platform=iOS Simulator,id=F218A46D-1C67-488A-A5AD-DE46317FD22B' \
  -derivedDataPath .build-evidence/DerivedData
```

Five Swift Testing tests and one XCUITest executed and passed:

- dailyCredit
- weeklyDistinctDays
- ignoresOtherActivitiesAndOutsideDates
- validatesGregorianDates
- validatesDraftsWithoutRequiringUniqueNames
- testLaunchesHost

Build output has no Swift compiler warnings. Xcode's metadata processor warns that extraction
was skipped because AppIntents.framework is not yet used (T05). Simulator runtime output also
reports failed Apple launch-measurement events and a duplicated Apple accessibility loader
class in its WebCore/WebKit bundles. These are recorded, not counted as app test failures.
Full local logs and xcresult are under ignored `.build-evidence/`.

## Remaining verification

No physical iPhone installation, signing, shortcut, persistence, history correction,
notification, restore, or transfer check has been performed. ClockReading requires dedicated
timezone/DST tests before use by the store. The full milestone remains pending T02–T05 and D2.

The plan helper cannot extract T01 because it requires headings named “Task 1”, while this
plan uses “T01”. Tasks are tracked directly until the helper format is reconciled; no task is
marked fully complete by the helper.
