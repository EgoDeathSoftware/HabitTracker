import AppIntents

struct HabitShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogActivityIntent(),
            phrases: ["Log an activity in \(.applicationName)"],
            shortTitle: "Log Activity",
            systemImageName: "plus.circle"
        )
    }
}
