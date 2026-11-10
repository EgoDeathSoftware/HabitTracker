import Foundation

actor HabitStore {
    private let controller: PersistenceController

    init(controller: PersistenceController) { self.controller = controller }

    func execute(_ command: HabitCommand, at: ClockReading) async throws -> MutationReceipt {
        try await controller.transaction { context in
            let original = try ManagedObjectMapping.load(context)
            var updated = original
            var receipt = try CommandRules.apply(command, to: &updated, at: at)
            if updated != original {
                updated.snapshot.revision += 1
                try ManagedObjectMapping.save(updated, in: context)
            }
            receipt = MutationReceipt(
                revision: updated.snapshot.revision, activityID: receipt.activityID,
                completionID: receipt.completionID, wasReplay: receipt.wasReplay,
                effectiveTargetDay: receipt.effectiveTargetDay
            )
            return receipt
        }
    }

    func snapshot(for query: SnapshotQuery = SnapshotQuery(),
                  at: ClockReading) async throws -> StoreSnapshot {
        try await controller.transaction { context in
            let original = try ManagedObjectMapping.load(context)
            var updated = original
            updated.snapshot.timeline = try PeriodRules.advance(state: original.snapshot.timeline, at: at)
            if updated != original {
                updated.snapshot.revision += 1
                try ManagedObjectMapping.save(updated, in: context)
            }
            var result = updated.snapshot
            if let id = query.activityID {
                result.timeline.activities.removeAll { $0.id != id }
                result.timeline.periods.removeAll { $0.activityID != id }
                result.completions.removeAll { $0.activityID != id }
            }
            if let range = query.range {
                result.timeline.periods.removeAll {
                    $0.range.end < range.start || $0.range.start > range.end
                }
                result.completions.removeAll { !range.contains($0.assignedDay) }
            }
            return result
        }
    }
}
