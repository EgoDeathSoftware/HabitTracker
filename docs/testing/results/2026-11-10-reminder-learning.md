# Reminder settings and learning

Reminder settings start disabled. Each habit stores its seed times, learned times, and grouped
adjustment history in the V2 local SQLite store. The app exposes unread changes on the activity
list and lets users acknowledge notices. iOS notification delivery is the next implementation step.

The full iOS 27.2 simulator suite passed with 34 domain tests and three UI tests. The UI flow
enabled reminders and verified the setting survived an app relaunch. The migration test created
an on-disk store with the bundled V1 model, reopened it with V2, and compared the tracking data,
including pending target and calendar changes. It then verified that an adjustment and its
acknowledgment survived reopening and that deleting the habit removed its reminder state.

Focused learning coverage includes the five-date threshold, exclusions, weekly first samples,
the daily movement cap, rollback, midnight median and spacing, and target increases/decreases.
Local logs are under `.build-evidence/t07-*.log`. Physical notification delivery and large-text
review remain open.
