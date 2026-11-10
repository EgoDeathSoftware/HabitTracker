import SwiftUI

struct ActivityDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let activityID: UUID
    @State private var editing = false
    @State private var deleting = false

    var body: some View {
        if let activity = environment.snapshot.timeline.activities.first(where: { $0.id == activityID }) {
            List {
                Section("Current goal") {
                    ActivityProgressView(activity: activity)
                    Button("Log one completion") { Task { await environment.log(activity) } }
                    if let confirmation = environment.confirmation { Text(confirmation).font(.callout) }
                    NavigationLink("Change target") { TargetEditorView(activity: activity) }
                    if let pending = activity.pendingTarget, let day = activity.pendingTargetStartDay {
                        Text("Target \(pending) starts \(day.description).")
                    }
                }
                Section {
                    NavigationLink("Edit recorded history") { HistoryEditorView(activityID: activityID) }
                    Button("Edit name and icon") { editing = true }
                }
                Section {
                    Button("Delete activity", role: .destructive) { deleting = true }
                } footer: {
                    Text("Deleting removes this activity and all its history from this app. "
                         + "Earlier exports and device backups are separate copies.")
                }
            }
            .navigationTitle(activity.name)
            .sheet(isPresented: $editing) { ActivityEditorView(activity: activity) }
            .alert("Delete \(activity.name)?", isPresented: $deleting) {
                Button("Cancel", role: .cancel) {}
                Button("Delete activity and history", role: .destructive) {
                    Task { if await environment.apply(.deleteActivity(activityID)) { dismiss() } }
                }
            } message: { Text("All recorded history and targets for \(activity.name) will be removed.") }
        } else {
            ContentUnavailableView("Activity unavailable", systemImage: "questionmark.folder")
        }
    }
}
