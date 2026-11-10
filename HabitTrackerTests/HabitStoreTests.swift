import Foundation
import CoreData
import Testing
@testable import HabitTracker

struct HabitStoreTests {
    private func setup() async throws -> (HabitStore, URL, ClockReading, UUID) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.sqlite")
        let controller = try await PersistenceController.open(storeURL: url)
        let store = HabitStore(controller: controller)
        let now = try ClockReading(
            instant: ISO8601DateFormatter().date(from: "2026-11-10T17:00:00Z")!,
            timeZone: TimeZone(identifier: "America/New_York")!
        )
        let id = UUID()
        _ = try await store.execute(.create(id, HabitDraft(
            name: "Read", symbolName: "book", cadence: .daily, target: 2
        )), at: now)
        return (store, url, now, id)
    }

    private func request(_ id: UUID, _ now: ClockReading) -> LogRequest {
        LogRequest(activityID: id, operationID: UUID(), assignedDay: now.localDay,
                   occurredAt: now.instant, captureTimeZoneID: now.timeZoneID, source: .app)
    }

    @Test func retryAndConcurrency() async throws {
        let (store, _, now, id) = try await setup()
        let input = request(id, now)
        _ = try await store.execute(.log(input), at: now)
        let replay = try await store.execute(.log(input), at: now)
        #expect(replay.wasReplay)
        #expect(try await store.snapshot(at: now).completions.count == 1)
        async let one = store.execute(.log(request(id, now)), at: now)
        async let two = store.execute(.log(request(id, now)), at: now)
        _ = try await (one, two)
        #expect(try await store.snapshot(at: now).completions.count == 3)
        let conflict = LogRequest(
            activityID: id, operationID: input.operationID, assignedDay: now.localDay,
            occurredAt: nil, captureTimeZoneID: now.timeZoneID, source: .manual
        )
        await #expect(throws: HabitError.operationConflict) {
            try await store.execute(.log(conflict), at: now)
        }
    }

    @Test func replayAfterRestartOrDeletion() async throws {
        let (store, url, now, id) = try await setup()
        let input = request(id, now)
        let receipt = try await store.execute(.log(input), at: now)
        let reopened = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        #expect(try await reopened.execute(.log(input), at: now).wasReplay)
        #expect(try await reopened.snapshot(at: now).completions.count == 1)
        _ = try await reopened.execute(.deleteCompletion(receipt.completionID!), at: now)
        #expect(try await reopened.execute(.log(input), at: now).wasReplay)
        #expect(try await reopened.snapshot(at: now).completions.isEmpty)
    }

    @Test func reopenPreservesHistory() async throws {
        let (store, url, now, id) = try await setup()
        _ = try await store.execute(.log(request(id, now)), at: now)
        let saved = try await store.snapshot(at: now)
        let reopened = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let restored = try await reopened.snapshot(at: now)
        #expect(restored == saved)
        #expect(try await reopened.snapshot(at: now).revision == saved.revision)
    }

    @Test func protectedStoreUnavailable() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let badURL = directory.appendingPathComponent("not-a-directory")
        try Data("existing file".utf8).write(to: badURL)
        await #expect(throws: HabitError.storeUnavailable) {
            try await PersistenceController.open(storeURL: badURL.appendingPathComponent("history.sqlite"))
        }
        #expect(try String(contentsOf: badURL, encoding: .utf8) == "existing file")
    }

    @Test func saveFailureIsAtomic() async throws {
        let (store, url, now, id) = try await setup()
        let before = try await store.snapshot(at: now)
        let input = request(id, now)
        // Inject an invalid mandatory attribute at the actual save boundary, on that queue.
        let observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextWillSave, object: nil, queue: nil
        ) { notification in
            guard let context = notification.object as? NSManagedObjectContext,
                  context.insertedObjects.contains(where: {
                      $0.entity.name == "Completion"
                          && $0.value(forKey: "operationID") as? UUID == input.operationID
                  }) else { return }
            for row in context.insertedObjects where row.entity.name == "Completion" {
                row.setValue(nil, forKey: "assignedDay")
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        await #expect(throws: HabitError.saveFailed) {
            try await store.execute(.log(input), at: now)
        }
        #expect(try await store.snapshot(at: now) == before)
        let reopened = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        #expect(try await reopened.snapshot(at: now) == before)
    }
}
