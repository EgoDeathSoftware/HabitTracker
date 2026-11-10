import Foundation
import Testing
@testable import HabitTracker

struct MigrationTests {
    @Test func v1ToV2PreservesData() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("migration.sqlite")
        let zone = TimeZone(secondsFromGMT: 0)!
        let day = try CalendarDay("2026-11-13")
        let now = try ClockReading(instant: day.midnight(in: zone).addingTimeInterval(36000),
                                   timeZone: zone)
        let id = UUID()
        let original = try await populateV1(at: url, id: id, now: now)
        let store = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let migrated = try await store.snapshot(at: now)
        #expect(migrated == original)
        #expect(migrated.reminders.isEmpty)
        #expect(migrated.notices.isEmpty)
        try await verifyReminderPersistence(store: store, url: url, id: id, now: now)
    }

    private func populateV1(at url: URL, id: UUID, now: ClockReading) async throws -> StoreSnapshot {
        let controller = try await PersistenceController.open(storeURL: url, modelVersion: "HabitTrackerV1")
        let store = HabitStore(controller: controller)
        let draft = try HabitDraft(name: "Read", symbolName: "book", cadence: .weekly, target: 2)
        _ = try await store.execute(.create(id, draft), at: now)
        _ = try await store.execute(.log(LogRequest(activityID: id, operationID: UUID(),
            assignedDay: now.localDay, occurredAt: now.instant,
            captureTimeZoneID: now.timeZoneID, source: .app)), at: now)
        _ = try await store.execute(.editTarget(TargetEdit(activityID: id, target: 3)), at: now)
        _ = try await store.execute(.changeWeekStart(7), at: now)
        let snapshot = try await store.snapshot(at: now)
        #expect(snapshot.timeline.activities.first?.pendingTarget == 3)
        #expect(snapshot.timeline.pendingCalendarSetting?.weekday == 7)
        return snapshot
    }

    private func verifyReminderPersistence(store: HabitStore, url: URL, id: UUID,
                                           now: ClockReading) async throws {
        _ = try await store.execute(.editReminders(.init(activityID: id, isEnabled: true,
                                                        minutes: [480])), at: now)
        for offset in 1...6 {
            let day = try now.localDay.adding(days: offset)
            let instant = day.midnight(in: now.timeZone).addingTimeInterval(36000)
            let at = try ClockReading(instant: instant, timeZone: now.timeZone)
            _ = try await store.execute(.log(LogRequest(activityID: id, operationID: UUID(),
                assignedDay: day, occurredAt: instant, captureTimeZoneID: at.timeZoneID,
                source: .app)), at: at)
        }
        let laterDay = try now.localDay.adding(days: 7)
        let later = try ClockReading(instant: laterDay.midnight(in: now.timeZone), timeZone: now.timeZone)
        let before = try await store.snapshot(at: later)
        let notice = try #require(before.notices.first)
        #expect(notice.changes.first?.newMinute == 510)
        _ = try await store.execute(.acknowledgeNotice(notice.id), at: later)
        let reopened = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let after = try await reopened.snapshot(at: later)
        #expect(after.reminders[id]?.slots.first?.effectiveMinute == 510)
        #expect(after.notices.first?.acknowledgedAt == later.instant)
        _ = try await reopened.execute(.deleteActivity(id), at: later)
        let deleted = try await reopened.snapshot(at: later)
        #expect(deleted.reminders.isEmpty)
        #expect(deleted.notices.isEmpty)
    }
}
