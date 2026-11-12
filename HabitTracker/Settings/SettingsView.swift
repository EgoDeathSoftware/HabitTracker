import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var weekday = 1

    var body: some View {
        Form {
            Section("Calendar") {
                Picker("Week starts", selection: $weekday) {
                    ForEach(1...7, id: \.self) { day in
                        Text(["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][day - 1])
                            .tag(day)
                    }
                }
                if let preview { Text("New weekly boundary: \(preview.description).") }
                Button("Save week start") { Task { _ = await environment.apply(.changeWeekStart(weekday)) } }
                if let pending = environment.snapshot.timeline.pendingCalendarSetting {
                    Text("Pending change takes effect \(pending.effectiveDay.description).")
                }
                Text("Closed weeks stay fixed. A shortened or extended transition week is excluded from success rates.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Your data") {
                NavigationLink("Export history") { ExportView() }
                Text("History stays on this device. No account or connection is needed.")
                Text("Device backups are controlled by your Apple settings. CSV export is a report, not a backup.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Settings")
        .onAppear {
            weekday = environment.snapshot.timeline.pendingCalendarSetting?.weekday
                ?? environment.snapshot.timeline.weekStartWeekday
        }
    }

    private var preview: CalendarDay? {
        guard let now = try? ClockReading(instant: Date(), timeZone: .current),
              let value = try? PeriodRules.changeWeekStart(
                state: environment.snapshot.timeline, weekday: weekday, at: now
              ) else { return nil }
        return value.pendingCalendarSetting?.effectiveDay
    }
}
