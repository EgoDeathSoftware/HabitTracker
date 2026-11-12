import SwiftUI
import UserNotifications

@main
struct HabitTrackerApp: App {
    @State private var environment = AppEnvironment.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationNavigation.shared
    }

    var body: some Scene {
        WindowGroup {
            ActivityListView()
                .environment(environment)
                .task { await environment.open() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    Task { await environment.refresh() }
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await environment.open() } }
                }
        }
    }
}
