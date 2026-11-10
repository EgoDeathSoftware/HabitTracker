import Foundation
import Testing
@testable import HabitTracker

struct HistoryTests {
    @Test func correctionsRecalculateTravelKeepsAssignedDayAndCascadeDelete() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.sqlite")
        let store = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let instant = ISO8601DateFormatter().date(from: "2026-11-10T17:00:00Z")!
        let now = try ClockReading(instant: instant, timeZone: TimeZone(identifier: "America/New_York")!)
        let actions = ActivityActions(store: store)
        let id = UUID()
        let otherID = UUID()
        let draft = try HabitDraft(name: "Read", symbolName: "book", cadence: .weekly, target: 2)
        _ = try await store.execute(.create(id, draft), at: now)
        _ = try await store.execute(.create(otherID, draft), at: now)
        let original = LogRequest(activityID: id, operationID: UUID(), assignedDay: now.localDay,
                                  occurredAt: instant, captureTimeZoneID: now.timeZoneID, source: .app)
        let saved = try await actions.retryLog(original, at: now)
        let tokyo = try ClockReading(instant: instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        #expect(try await store.snapshot(at: tokyo).completions[0].assignedDay == now.localDay)
        let previous = try CalendarDay("2026-11-08")
        _ = try await store.execute(.editCompletion(CompletionEdit(
            completionID: saved.completionID!, assignedDay: previous,
            occurredAt: nil, captureTimeZoneID: now.timeZoneID
        )), at: now)
        let edited = try await store.snapshot(at: now)
        #expect(edited.completions[0].occurredAt == nil)
        #expect(edited.completions[0].wasTimeOrDateEdited)
        #expect(edited.timeline.activities.first { $0.id == id }?.trackingStartDay == previous)
        let otherBefore = try await store.snapshot(for: SnapshotQuery(activityID: otherID), at: now)
        _ = try await store.execute(.deleteActivity(id), at: now)
        let deleted = try await store.snapshot(at: now)
        #expect(deleted.completions.isEmpty)
        #expect(deleted.timeline.periods.allSatisfy { $0.activityID == otherID })
        let otherAfter = try await store.snapshot(for: SnapshotQuery(activityID: otherID), at: now)
        #expect(otherBefore.timeline == otherAfter.timeline)
        await #expect(throws: HabitError.activityUnavailable) {
            try await store.execute(.log(original), at: now)
        }
    }
}
