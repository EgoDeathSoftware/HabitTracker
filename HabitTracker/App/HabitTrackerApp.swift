import SwiftUI

@main
struct HabitTrackerApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ActivityListView()
                .environment(environment)
                .task { await environment.open() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.open() } }
                }
        }
    }
}
