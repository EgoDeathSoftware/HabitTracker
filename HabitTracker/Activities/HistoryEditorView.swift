import SwiftUI

struct HistoryEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    let activityID: UUID
    @State private var adding = false

    var body: some View {
        List {
            let entries = environment.snapshot.completions.filter { $0.activityID == activityID }
                .sorted { $0.assignedDay > $1.assignedDay }
            if entries.isEmpty { Text("No entries yet. Log now or add a missed entry.") }
            ForEach(entries) { entry in
                NavigationLink {
                    CompletionEditorView(activityID: activityID, entry: entry)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.assignedDay.description)
                        if let time = entry.occurredAt {
                            Text(time.formatted(date: .omitted, time: .shortened)
                                 + " · " + entry.captureTimeZoneID).font(.caption)
                        } else { Text("Date only").font(.caption) }
                        if entry.wasTimeOrDateEdited { Text("Corrected entry").font(.caption) }
                    }
                }
            }
        }
        .navigationTitle("Recorded history")
        .toolbar { Button("Add missed entry", systemImage: "plus") { adding = true } }
        .sheet(isPresented: $adding) {
            NavigationStack { CompletionEditorView(activityID: activityID) }
        }
    }
}

struct CompletionEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let activityID: UUID
    let entry: CompletionSnapshot?
    @State private var date: Date
    @State private var includeTime: Bool
    @State private var extendWarning = false
    @State private var deleting = false
    @State private var saving = false
    private let zone: TimeZone
    private let operationID = UUID()

    init(activityID: UUID, entry: CompletionSnapshot? = nil) {
        self.activityID = activityID
        self.entry = entry
        let zone = entry.flatMap { TimeZone(identifier: $0.captureTimeZoneID) } ?? .current
        self.zone = zone
        _date = State(initialValue: entry?.occurredAt ?? entry?.assignedDay.midnight(in: zone) ?? Date())
        _includeTime = State(initialValue: entry?.occurredAt != nil)
    }

    var body: some View {
        Form {
            DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            Toggle("Include actual time", isOn: $includeTime)
            if includeTime {
                DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
            }
            Text("Time zone: \(zone.identifier)").font(.footnote)
            Text("Manual and corrected entries update progress but do not train reminders.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Save entry") { checkExtension() }.disabled(saving)
            if entry != nil { Button("Delete entry", role: .destructive) { deleting = true } }
        }
        .environment(\.timeZone, zone)
        .navigationTitle(entry == nil ? "Missed entry" : "Correct entry")
        .alert("Extend tracking history?", isPresented: $extendWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Extend and save") { Task { await save() } }
        } message: {
            Text("This date is before tracking began. Earlier periods will use the initial target, "
                 + "including days with no entries.")
        }
        .alert("Delete this entry?", isPresented: $deleting) {
            Button("Cancel", role: .cancel) {}
            Button("Delete entry", role: .destructive) {
                Task {
                    if let entry, await environment.apply(.deleteCompletion(entry.id)) { dismiss() }
                }
            }
        } message: { Text("Progress will be recalculated. The activity will remain.") }
    }

    private func checkExtension() {
        guard let day = try? ClockReading(instant: date, timeZone: zone).localDay else { return }
        if let activity = environment.snapshot.timeline.activities.first(where: { $0.id == activityID }),
           day < activity.trackingStartDay { extendWarning = true }
        else { Task { await save() } }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            let day = try ClockReading(instant: date, timeZone: zone).localDay
            let command: HabitCommand
            if let entry {
                command = .editCompletion(CompletionEdit(
                    completionID: entry.id, assignedDay: day, occurredAt: includeTime ? date : nil,
                    captureTimeZoneID: zone.identifier
                ))
            } else {
                command = .log(LogRequest(
                    activityID: activityID, operationID: operationID, assignedDay: day,
                    occurredAt: includeTime ? date : nil, captureTimeZoneID: zone.identifier, source: .manual
                ))
            }
            if await environment.apply(command) { dismiss() }
        } catch { environment.errorMessage = error.localizedDescription }
    }
}
