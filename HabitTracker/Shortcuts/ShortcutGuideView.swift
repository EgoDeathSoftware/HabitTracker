import SwiftUI

struct ShortcutGuideView: View {
    let activity: ActivitySnapshot

    var body: some View {
        List {
            Section {
                Text("Set up a shortcut for \(activity.name)").font(.headline)
                Label("Activity code: \(ActivityEntity.code(for: activity.id))", systemImage: activity.symbolName)
                Text("One tap records one occurrence. It meets a once-daily goal, contributes one "
                     + "completion toward a multiple-daily goal, or gives one distinct day toward a "
                     + "weekly goal if you have not already logged that day.")
            }
            Section("Set up in Shortcuts") {
                step(1, "Create a shortcut", "Open Apple’s Shortcuts app and tap + to create a shortcut.")
                step(2, "Add Log Activity", "Search for Log Activity and add the action from Habit Tracker.")
                step(3, "Choose this activity", "Tap Activity in the action and choose \(activity.name). "
                     + "If names match, compare the icon and activity code above. Select a fixed activity "
                     + "instead of Ask Each Time.")
                step(4, "Add to Home Screen", "Name the shortcut. Open the shortcut’s menu and choose "
                     + "Add to Home Screen. Pick a recognizable Home Screen name and icon, then tap Add.")
                step(5, "Try the icon", "Tap the new icon once and check the updated progress or history. "
                     + "This records a real completion now. If you were testing, remove that entry in "
                     + "Edit recorded history.")
            }
            Section("If something is missing") {
                Text("Action or activity missing? Save the activity in Habit Tracker first, then reopen "
                     + "Shortcuts and search for Log Activity again.")
                Text("Asked to choose an activity each time? Edit the shortcut and reselect a saved "
                     + "activity as its fixed Activity parameter.")
                Text("Activity deleted? Remove the obsolete shortcut and create one for a saved activity.")
                Text("Renaming an activity keeps the shortcut connected. You can edit its Home Screen "
                     + "label yourself. Reading this guide never records an entry.")
            }
        }
        .navigationTitle("Home Screen shortcut")
    }

    private func step(_ number: Int, _ title: String, _ instructions: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(number). \(title)").font(.headline)
            Text(instructions).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
