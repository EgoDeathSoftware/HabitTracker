import SwiftUI

struct ActivityListView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showingEditor = false

    var body: some View {
        @Bindable var router = environment.router
        NavigationStack(path: $router.path) {
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
            .navigationDestination(for: UUID.self) { ActivityDetailView(activityID: $0) }
            .onChange(of: router.path) { _, _ in showingEditor = false }
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
        .id(router.navigationID)
    }

    private var activityList: some View {
        List {
            if environment.needsRefresh {
                Section {
                    Text("Your saved data could not be refreshed. Refresh history before checking the latest counts.")
                    Button("Refresh history") { Task { await environment.refresh() } }
                }
            }
            if let confirmation = environment.confirmation {
                Label(confirmation, systemImage: "checkmark.circle")
                    .font(.callout).accessibilityAddTraits(.updatesFrequently)
            }
            ForEach(environment.failedLogs, id: \.operationID) { request in
                Button("Retry unsaved completion") { Task { await environment.retry(request) } }
            }
            ForEach(environment.snapshot.notices.filter { $0.acknowledgedAt == nil }) { notice in
                if let activity = environment.snapshot.timeline.activities.first(where: {
                    $0.id == notice.activityID
                }) {
                    NavigationLink {
                        ReminderNoticesView(activityID: activity.id)
                    } label: {
                        Label("Reminder times adjusted for \(activity.name)", systemImage: "clock")
                    }
                }
            }
            if environment.snapshot.timeline.activities.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Start with one activity").font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Add an activity and choose your daily or weekly target.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
            }
            ForEach(environment.snapshot.timeline.activities) { activity in
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                    : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
                layout {
                    NavigationLink(value: activity.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: activity.symbolName).accessibilityHidden(true)
                                Text(activity.name)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .layoutPriority(1)
                            }
                            .font(.headline)
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
