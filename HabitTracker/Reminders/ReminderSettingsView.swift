import SwiftUI

struct ReminderSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let activity: ActivitySnapshot
    @State private var enabled: Bool
    @State private var minutes: [Int]
    @State private var saving = false

    init(activity: ActivitySnapshot, configuration: ReminderConfiguration?) {
        self.activity = activity
        let count = activity.cadence == .weekly ? 1 : activity.effectiveTarget
        let stored = configuration?.slots.map(\.effectiveMinute) ?? []
        _enabled = State(initialValue: configuration?.isEnabled ?? false)
        _minutes = State(initialValue: stored.count == count ? stored : (0..<count).map { 540 + $0 * 60 })
    }

    var body: some View {
        Form {
            Toggle("Reminders", isOn: $enabled)
            if enabled {
                Section {
                    ReminderTimeFields(minutes: $minutes)
                } footer: {
                    Text("Keep times at least 30 minutes apart, including overnight. Times adapt gradually after five qualifying days.")
                }
            }
            Text("Reminders cover the next 28 days, up to 60 upcoming notifications across your habits. Open the app regularly to refresh coverage. iOS controls delivery timing.")
                .font(.footnote).foregroundStyle(.secondary)
            if let message = environment.notificationMessage { Text(message) }
            Button("Save reminder settings") {
                saving = true
                Task {
                    if enabled { await environment.enableNotificationPermission() }
                    let edit = ReminderEdit(activityID: activity.id, isEnabled: enabled, minutes: minutes)
                    if await environment.apply(.editReminders(edit)) { dismiss() }
                    saving = false
                }
            }
            .disabled(saving || (enabled && !ReminderLearning.validMinutes(minutes)))
        }
        .navigationTitle("Reminders")
    }
}

struct ReminderTimeFields: View {
    @Binding var minutes: [Int]
    var firstSlot = 1

    var body: some View {
        ForEach(minutes.indices, id: \.self) { index in
            DatePicker("Reminder \(firstSlot + index)", selection: Binding(
                get: { Date(timeIntervalSince1970: Double(minutes[index] * 60)) },
                set: { value in
                    if let clock = try? ClockReading(instant: value, timeZone: .gmt) {
                        minutes[index] = clock.localMinute
                    }
                }), displayedComponents: .hourAndMinute)
        }
        .environment(\.timeZone, .gmt)
    }
}

struct ReminderNoticesView: View {
    @Environment(AppEnvironment.self) private var environment
    let activityID: UUID

    var body: some View {
        let notices = environment.snapshot.notices.filter { $0.activityID == activityID }
        List {
            if notices.isEmpty { Text("No reminder adjustments yet.") }
            ForEach(notices.reversed()) { notice in
                Section(notice.createdAt.formatted(date: .abbreviated, time: .omitted)) {
                    Text(notice.reason)
                    ForEach(notice.changes, id: \.slotIndex) { change in
                        Text("Reminder \(change.slotIndex + 1), \(time(change.oldMinute)) to \(time(change.newMinute))")
                    }
                    if notice.acknowledgedAt == nil {
                        Button("Mark as read") {
                            Task { _ = await environment.apply(.acknowledgeNotice(notice.id)) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminder adjustments")
    }

    private func time(_ minute: Int) -> String {
        let date = Date(timeIntervalSince1970: Double(minute * 60))
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: .gmt))
    }
}
