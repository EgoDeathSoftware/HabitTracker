# Stage A — iPhone handoff, November 10, 2026

The app includes persistent activity creation, one-tap app logging, history correction,
target/calendar settings, and the foreground **Log Activity** App Intent with a bundled guide.
App and shortcut logging share the SQLite transaction path. Shortcut selection uses stable
activity UUIDs; duplicate names can be distinguished by icon and activity code.

## Build evidence

- Xcode 27.2 (27B52), iOS 27.2 iPhone 18 Pro simulator.
- Full simulator suite succeeded: 25 domain/store/intent tests and three UI tests. UI checks
  covered creation, logging, date-only correction, relaunch with saved history, deletion
  confirmation, and reopening the shortcut guide without logging.
- Generic iPhone build succeeded with `CODE_SIGNING_ALLOWED=NO`. The app bundle declares
  `MinimumOSVersion = 26.0`, and `Metadata.appintents/extract.actionsdata` includes
  `LogActivityIntent`, `Log Activity`, and `ActivityEntity`.
- Local logs: `.build-evidence/t05-final-device.log` and `.build-evidence/t05-verified-suite.log`.
- App Intent runtime mode follows Apple's [supportedModes documentation](https://developer.apple.com/documentation/appintents/appintent/supportedmodes).
  Compiled metadata verifies packaging, not system execution on an iPhone.

## Physical device gate: blocked

`xcrun devicectl list devices` listed only the simulator. No physical device installation,
signing, system Shortcuts run, or iOS 26 guide-label validation was performed.

1. Connect and unlock the intended iOS 26 iPhone, trust/pair it with this Mac, and make it
   available as an Xcode run destination. If needed, enable Developer Mode on the phone.
2. Open `HabitTracker.xcodeproj`, choose the HabitTracker scheme and the iPhone destination.
   Select the owner's development team in Signing & Capabilities as needed for local testing.
   Build and run; do not treat the unsigned generic build as an installable build.
3. Create a daily habit. Log once from the app and verify one saved entry. Follow the bundled
   Home Screen shortcut guide without verbal help, then tap the new icon and verify one more
   entry and the in-app confirmation. Correct one entry and check both entries after relaunch.
4. Complete [D2](../acceptance-matrix.md#d2--actual-home-screen-setup) for cold/warm launch,
   fixed parameters, target variants, rename, duplicate names, deletion, and offline guide use.
   Record the phone model, iOS version, build/commit, and observed results here.

Stage B remains pending the physical D2 gate in the accepted plan. Backup and phone transfer
are later device procedures and remain unverified.
