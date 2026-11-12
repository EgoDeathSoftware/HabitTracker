import Foundation
import Testing
@testable import HabitTracker

struct SchedulerTests {
    @MainActor @Test func permissionRequestError() async {
        let client = TestNotificationClient()
        await client.setAuthorization(.notDetermined)
        await client.setFailure(true)
        let environment = AppEnvironment()
        await environment.enableNotificationPermission(client: client)
        #expect(environment.notificationMessage?.contains("could not be requested") == true)
        await client.setFailure(false)
        await client.setAuthorization(.denied)
        await environment.enableNotificationPermission(client: client)
        #expect(environment.notificationMessage?.contains("iPhone Settings") == true)
    }

    @Test func concurrentCallers() async {
        let client = TestNotificationClient()
        await client.seed("habit.stale")
        let scheduler = NotificationScheduler(client: client, snapshot: { StoreSnapshot() })
        let outcomes = await withTaskGroup(of: ScheduleOutcome.self) { group in
            for _ in 0..<20 { group.addTask { await scheduler.reconcile() } }
            var values: [ScheduleOutcome] = []
            for await value in group { values.append(value) }
            return values
        }
        #expect(outcomes.count == 20)
        #expect(outcomes.allSatisfy { $0 == .scheduled })
        #expect(await client.pendingIDs().isEmpty)
    }

    @Test func failureKeepsSavedLog() async throws {
        let now = try ClockReading(instant: Date(), timeZone: .current)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("test.sqlite")
        let store = HabitStore(controller: try await PersistenceController.open(storeURL: url))
        let id = UUID()
        _ = try await store.execute(.create(id, HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 2)), at: now)
        _ = try await store.execute(.editReminders(ReminderEdit(activityID: id, isEnabled: true, minutes: [540, 1080])), at: now)
        let client = TestNotificationClient()
        await client.setFailure(true)
        let scheduler = NotificationScheduler(client: client, snapshot: { try await store.snapshot(at: now) }, clock: { now })
        #expect(await scheduler.reconcile() == .failed)
        let actions = ActivityActions(store: store, scheduler: scheduler)
        let request = LogRequest(activityID: id, operationID: UUID(), assignedDay: now.localDay,
            occurredAt: now.instant, captureTimeZoneID: now.timeZoneID, source: .app)
        let receipt = try await actions.retryLog(request, at: now)
        #expect(receipt.completionID != nil)
        #expect(try await store.snapshot(at: now).completions.count == 1)
        #expect(await actions.pendingRetries().isEmpty)
        await client.setFailure(false)
        #expect(await scheduler.reconcile() == .scheduled)
        #expect(await client.pendingIDs().isEmpty == false)
        let replay = try await actions.retryLog(request, at: now)
        #expect(replay.wasReplay)
        #expect(try await store.snapshot(at: now).completions.count == 1)
    }

    @Test func latestRevisionWins() async throws {
        let now = try ClockReading(instant: Date(timeIntervalSince1970: 1794268800), timeZone: .gmt)
        let id = UUID()
        let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 1), at: now)
        let config = ReminderConfiguration(activityID: id, isEnabled: true, target: 1,
            learningStartedAt: now.instant, learningStartDay: now.localDay,
            slots: [ReminderSlot(minute: 540)])
        let state = SchedulerState(StoreSnapshot(timeline: TimelineState(activities: [activity]), reminders: [id: config]))
        let client = TestNotificationClient()
        await client.suspendNextAdd()
        let scheduler = NotificationScheduler(client: client, snapshot: { await state.read() }, clock: { now })
        let first = Task { await scheduler.reconcile() }
        await client.waitForSuspension()
        await state.deleteAll()
        await client.resumeAdd()
        #expect(await first.value == .scheduled)
        #expect(await client.pendingIDs().isEmpty)
    }

    @Test func deniedFailureAndReplay() async throws {
        let client = TestNotificationClient()
        let scheduler = NotificationScheduler(client: client, snapshot: { StoreSnapshot() })
        await client.setAuthorization(.denied)
        #expect(await scheduler.reconcile() == .permissionRequired)
        await client.setAuthorization(.authorized)
        await client.seed("habit.stale")
        #expect(await scheduler.reconcile() == .scheduled)
        #expect(await client.pendingIDs().isEmpty)
        #expect(await scheduler.reconcile() == .scheduled)
    }
}

actor TestNotificationClient: NotificationClient {
    private var state: NotificationAuthorization = .authorized
    private var ids: Set<String> = []
    private var suspend = false
    private var suspended: CheckedContinuation<Void, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private var fails = false
    func setFailure(_ value: Bool) { fails = value }
    func suspendNextAdd() { suspend = true }
    func waitForSuspension() async {
        if suspended != nil { return }
        await withCheckedContinuation { observer = $0 }
    }
    func resumeAdd() { suspended?.resume(); suspended = nil }
    func setAuthorization(_ value: NotificationAuthorization) { state = value }
    func seed(_ id: String) { ids.insert(id) }
    func authorization() -> NotificationAuthorization { state }
    func requestAuthorization() throws -> Bool {
        if fails { throw HabitError.storeUnavailable }
        return state == .authorized
    }
    func pendingIDs() -> Set<String> { ids }
    func remove(ids: Set<String>) { self.ids.subtract(ids) }
    func add(_ request: PlannedNotification) async throws {
        if fails { throw HabitError.saveFailed }
        if suspend {
            suspend = false
            await withCheckedContinuation { continuation in
                suspended = continuation
                observer?.resume()
                observer = nil
            }
        }
        ids.insert(request.id)
    }
}

actor SchedulerState {
    private var value: StoreSnapshot
    init(_ value: StoreSnapshot) { self.value = value }
    func read() -> StoreSnapshot { value }
    func deleteAll() { value = StoreSnapshot(revision: value.revision + 1) }
}
