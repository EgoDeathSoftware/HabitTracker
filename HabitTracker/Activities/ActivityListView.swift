import SwiftUI

struct ActivityListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var showingEditor = false

    var body: some View {
        @Bindable var environment = environment
        NavigationStack {
            Group {
                if environment.isReady { activityList }
                else if environment.isOpening { ProgressView("Opening local history…") }
                else {
                    ContentUnavailableView {
                        Label("History unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text(environment.errorMessage ?? "Retry opening your local data.")
                    } actions: {
                        Button("Retry opening data") { Task { await environment.open() } }
                    }
                }
            }
            .navigationTitle("Habit Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gear") }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingEditor = true } label: { Label("Add activity", systemImage: "plus") }
                        .disabled(!environment.isReady)
                }
            }
            .sheet(isPresented: $showingEditor) { ActivityEditorView() }
            .alert("Change could not be saved", isPresented: Binding(
                get: { environment.isReady && environment.errorMessage != nil },
                set: { if !$0 { environment.errorMessage = nil } }
            )) {
                Button("OK") { environment.errorMessage = nil }
            } message: { Text(environment.errorMessage ?? "Please try again.") }
        }
    }

    private var activityList: some View {
        List {
            if let confirmation = environment.confirmation {
                Label(confirmation, systemImage: "checkmark.circle")
                    .font(.callout).accessibilityAddTraits(.updatesFrequently)
                    .task(id: confirmation) {
                        try? await Task.sleep(for: .seconds(3))
                        if environment.confirmation == confirmation { environment.confirmation = nil }
                    }
            }
            ForEach(environment.failedLogs, id: \.operationID) { request in
                Button("Retry unsaved completion") { Task { await environment.retry(request) } }
            }
            if environment.snapshot.timeline.activities.isEmpty {
                ContentUnavailableView("Start with one activity", systemImage: "checkmark.circle",
                                       description: Text("Add an activity and choose your daily or weekly target."))
            }
            ForEach(environment.snapshot.timeline.activities) { activity in
                HStack(alignment: .center, spacing: 16) {
                    NavigationLink {
                        ActivityDetailView(activityID: activity.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(activity.name, systemImage: activity.symbolName).font(.headline)
                            ActivityProgressView(activity: activity)
                        }
                    }
                    .accessibilityLabel("Open \(activity.name)")
                    Button { Task { await environment.log(activity) } } label: {
                        Image(systemName: "plus.circle.fill").font(.title).frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Log \(activity.name)")
                    .accessibilityHint("Records one completion now.")
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct ActivityProgressView: View {
    @Environment(AppEnvironment.self) private var environment
    let activity: ActivitySnapshot

    var body: some View {
        if let period = environment.currentPeriod(for: activity) {
            let progress = GoalRules.progress(period: period, completions: environment.snapshot.completions)
            let unit = activity.cadence == .daily ? "completions" : "distinct days this week"
            Text("\(progress.creditedUnits) of \(progress.target) \(unit)")
                .font(.subheadline).foregroundStyle(.secondary)
            if progress.rawCount > progress.creditedUnits {
                Text("\(progress.rawCount) total entries").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
