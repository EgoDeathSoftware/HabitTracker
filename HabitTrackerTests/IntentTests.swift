import CoreData
import Foundation
import Testing
@testable import HabitTracker

@MainActor
struct IntentTests {
    @Test func notificationTapOnlyNavigates() async throws {
        let (store, environment, id, now) = try await setup()
        await environment.openNotification(activityID: id)
        #expect(environment.router.path == [id])
        #expect(environment.router.confirmation == nil)
        #expect(try await store.snapshot(at: now).completions.isEmpty)
        await environment.openNotification(activityID: UUID())
        #expect(environment.router.path == [id])
    }

    private func setup() async throws -> (HabitStore, AppEnvironment, UUID, ClockReading) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.sqlite")
        let store = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let now = try ClockReading(instant: Date(), timeZone: .current)
        let id = UUID()
        _ = try await store.execute(.create(id, HabitDraft(
            name: "Read", symbolName: "book", cadence: .daily, target: 2
        )), at: now)
        return (store, AppEnvironment(store: store), id, now)
    }

    @Test func confirmationAfterSave() async throws {
        let (store, environment, id, _) = try await setup()
        try await environment.recordShortcut(activityID: id)
        let now = try ClockReading(instant: Date(), timeZone: .current)
        let saved = try await store.snapshot(at: now)
        #expect(saved.completions.count == 1)
        #expect(saved.completions.first?.source == .shortcut)
        #expect(environment.router.confirmation?.completionID == saved.completions.first?.id)
        environment.router.showActivity(id: id, confirmation: environment.router.confirmation)
        #expect(try await store.snapshot(at: now).completions.count == 1)
    }

    @Test func noSuccessOnSaveFailure() async throws {
        let (store, environment, id, now) = try await setup()
        let observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextWillSave, object: nil, queue: nil
        ) { notification in
            guard let context = notification.object as? NSManagedObjectContext else { return }
            for row in context.insertedObjects where row.entity.name == "Completion"
                && row.value(forKey: "activityID") as? UUID == id {
                row.setValue(nil, forKey: "assignedDay")
            }
        }
        defer { NotificationCenter.default.removeObserver(observer) }
        do {
            try await environment.recordShortcut(activityID: id)
            Issue.record("A failed save must throw")
        } catch let error as HabitError {
            #expect(error == .saveFailed)
        }
        #expect(environment.router.confirmation == nil)
        #expect(try await store.snapshot(at: now).completions.isEmpty)
    }

    @Test func fixedActivityParameterSurvivesRenameAndDeletion() async throws {
        let (store, environment, id, now) = try await setup()
        let query = ActivityEntityQuery(store: store)
        let original = try #require(try await query.entities(for: [id]).first)
        #expect(original.id == id)
        _ = try await store.execute(.rename(id, name: "Read more", symbolName: "book"), at: now)
        let renamed = try #require(try await query.entities(for: [original.id]).first)
        #expect(renamed.id == original.id && renamed.name == "Read more")
        _ = try await store.execute(.deleteActivity(id), at: now)
        #expect(try await query.entities(for: [original.id]).isEmpty)
        do {
            try await environment.recordShortcut(activityID: original.id)
            Issue.record("Deleted activities cannot be logged")
        } catch let error as HabitError {
            #expect(error == .activityUnavailable)
        }
        #expect(environment.router.confirmation == nil)
        #expect(try await store.snapshot(at: now).completions.isEmpty)
    }
}
