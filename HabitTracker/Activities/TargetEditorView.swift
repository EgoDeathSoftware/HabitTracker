import SwiftUI

struct TargetEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let activity: ActivitySnapshot
    @State private var target: Int
    @State private var saving = false

    init(activity: ActivitySnapshot) {
        self.activity = activity
        _target = State(initialValue: activity.pendingTarget ?? activity.effectiveTarget)
    }

    var body: some View {
        Form {
            Stepper("Target: \(target)", value: $target, in: 1...(activity.cadence == .daily ? 10 : 7))
            Text(preview).font(.callout)
            Text("Completed periods keep their targets. Corrections to their entries still change progress.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Save target") {
                saving = true
                Task {
                    if await environment.apply(.editTarget(TargetEdit(activityID: activity.id, target: target))) {
                        dismiss()
                    }
                    saving = false
                }
            }.disabled(saving)
        }
        .navigationTitle("Target")
    }

    private var preview: String {
        do {
            let now = try ClockReading(instant: Date(), timeZone: .current)
            let proposed = try PeriodRules.editTarget(
                state: environment.snapshot.timeline,
                edit: TargetEdit(activityID: activity.id, target: target), at: now
            )
            let updated = proposed.activities.first { $0.id == activity.id }!
            if let day = updated.pendingTargetStartDay { return "Target \(target) starts \(day.description)." }
            if target == activity.effectiveTarget && activity.pendingTarget != nil {
                return "Keep target \(target) and cancel the pending change."
            }
            let day = proposed.periods.first { $0.activityID == activity.id && $0.closedAt == nil }?.range.start
            return "Target \(target) applies to the period starting \(day?.description ?? now.localDay.description)."
        } catch { return error.localizedDescription }
    }
}
