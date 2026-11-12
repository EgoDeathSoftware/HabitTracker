import Foundation
import Testing
@testable import HabitTracker

struct RestoreTests {
    @Test func reopenStoreReconciles() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("source")
        let restored = directory.appendingPathComponent("restored")
        let url = source.appendingPathComponent("history.sqlite")
        let controller = try await PersistenceController.open(storeURL: url)
        let store = HabitStore(controller: controller)
        let day = try CalendarDay("2026-11-13")
        let now = try ClockReading(instant: day.midnight(in: .gmt).addingTimeInterval(36000), timeZone: .gmt)
        let id = UUID()
        _ = try await store.execute(.create(id, HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .weekly, target: 2)), at: now)
        let request = LogRequest(activityID: id, operationID: UUID(), assignedDay: day,
            occurredAt: nil, captureTimeZoneID: now.timeZoneID, source: .manual)
        _ = try await store.execute(.log(request), at: now)
        _ = try await store.execute(.editReminders(ReminderEdit(activityID: id, isEnabled: true, minutes: [540])), at: now)
        _ = try await store.execute(.editTarget(TargetEdit(activityID: id, target: 3)), at: now)
        _ = try await store.execute(.changeWeekStart(7), at: now)
        try await controller.transaction { context in
            var value = try ManagedObjectMapping.load(context)
            value.snapshot.notices.append(AdjustmentNotice(id: UUID(), activityID: id,
                createdAt: now.instant, reason: "Learned reminder time",
                changes: [ReminderChange(slotIndex: 0, oldMinute: 540, newMinute: 570)]))
            value.snapshot.reminders[id]?.slots[0].effectiveMinute = 570
            value.snapshot.revision += 1
            try ManagedObjectMapping.save(value, in: context)
        }
        let saved = try await store.snapshot(at: now)
        #expect(saved.notices.first?.acknowledgedAt == nil)
        #expect(FileManager.default.fileExists(atPath: url.path + "-wal"))
        // The writer is idle for this complete directory copy, including committed WAL data.
        try FileManager.default.copyItem(at: source, to: restored)
        let reopened = HabitStore(controller: try await PersistenceController.open(storeURL: restored.appendingPathComponent("history.sqlite")))
        #expect(try await reopened.snapshot(at: now) == saved)
        #expect(try await reopened.execute(.log(request), at: now).wasReplay)
        let client = TestNotificationClient()
        await client.seed("habit.stale")
        let scheduler = NotificationScheduler(client: client, snapshot: { try await reopened.snapshot(at: now) }, clock: { now })
        #expect(await scheduler.reconcile() == .scheduled)
        #expect(await client.pendingIDs() == Set(NotificationPlanner.plan(snapshot: saved, at: now).map(\.id)))
    }

    @Test func failureDoesNotReset() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("damaged.sqlite")
        let original = Data("unreadable store fixture".utf8)
        try original.write(to: url)
        await #expect(throws: HabitError.storeUnavailable) {
            try await PersistenceController.open(storeURL: url)
        }
        #expect(try Data(contentsOf: url) == original)
        let validURL = directory.appendingPathComponent("valid.sqlite")
        let valid = HabitStore(controller: try await PersistenceController.open(storeURL: validURL))
        let now = try ClockReading(instant: Date(), timeZone: .gmt)
        _ = try await valid.execute(.create(UUID(), HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 1)), at: now)
        let inventory = try await valid.snapshot(at: now)
        await #expect(throws: HabitError.storeUnavailable) {
            try await PersistenceController.open(storeURL: validURL, modelVersion: "UnavailableModel")
        }
        let retried = HabitStore(controller: try await PersistenceController.open(storeURL: validURL))
        #expect(try await retried.snapshot(at: now) == inventory)
        await #expect(throws: HabitError.storeUnavailable) {
            try await PersistenceController.open(storeURL: url, modelVersion: "UnavailableModel")
        }
        #expect(try Data(contentsOf: url) == original)
    }
}
