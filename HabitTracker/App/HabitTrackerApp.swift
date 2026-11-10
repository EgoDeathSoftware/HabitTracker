import SwiftUI

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentUnavailableView(
                "Habit Tracker",
                systemImage: "checkmark.circle",
                description: Text("Activity tracking is under development.")
            )
        }
    }
}
