import Foundation
import Observation

@MainActor @Observable
final class AppEnvironment {
    static let shared = AppEnvironment()
    let router = AppRouter()
    var snapshot = StoreSnapshot()
    var isReady = false
    var isOpening = false
    var errorMessage: String?
    var needsRefresh = false
    var confirmation: String?
    var failedLogs: [LogRequest] = []
    private(set) var store: HabitStore?
    private(set) var actions: ActivityActions?
    private(set) var scheduler: NotificationScheduler?
    var notificationMessage: String?
    private var openingTask: Task<Void, Never>?
    @ObservationIgnored private var confirmationTask: Task<Void, Never>?
    @ObservationIgnored private let snapshotReader: (@Sendable (HabitStore) async throws -> StoreSnapshot)?

    init(store: HabitStore? = nil,
         snapshotReader: (@Sendable (HabitStore) async throws -> StoreSnapshot)? = nil) {
        self.snapshotReader = snapshotReader
        if let store {
            self.store = store
            configureActions(store)
            isReady = true
        }
    }

    func open() async {
        if let openingTask { await openingTask.value; return }
        if isReady { await refresh(); return }
        let task = Task { await loadStore() }
        openingTask = task
        await task.value
        openingTask = nil
    }

    private func loadStore() async {
        isOpening = true
        defer { isOpening = false }
        do {
            try? CSVExporter.removeInterruptedExports()
            let root = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            )
            var directory = root.appendingPathComponent("HabitTracker", isDirectory: true)
            #if targetEnvironment(simulator)
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                directory = root.appendingPathComponent("HabitTrackerUITests", isDirectory: true)
                if ProcessInfo.processInfo.arguments.contains("-reset-test-store"),
                   FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.removeItem(at: directory)
                }
            }
            #endif
            let controller = try await PersistenceController.open(
                storeURL: directory.appendingPathComponent("HabitTracker.sqlite")
            )
            let store = HabitStore(controller: controller)
            self.store = store
            configureActions(store)
            try await reload()
            isReady = true
            errorMessage = nil
            if let scheduler { _ = await scheduler.reconcile() }
        } catch { errorMessage = error.localizedDescription }
    }

    func refresh() async {
        do {
            try await reload()
            needsRefresh = false
            if let scheduler { _ = await scheduler.reconcile() }
        }
        catch { needsRefresh = true }
    }

    private func configureActions(_ store: HabitStore) {
        let scheduler = NotificationScheduler(client: SystemNotificationClient(), snapshot: {
            try await store.snapshot(at: ClockReading(instant: Date(), timeZone: .current))
        })
        self.scheduler = scheduler
        actions = ActivityActions(store: store, scheduler: scheduler)
    }

    func enableNotificationPermission(client: any NotificationClient = SystemNotificationClient()) async {
        do {
            if await client.authorization() == .notDetermined {
                _ = try await client.requestAuthorization()
            }
            let status = await client.authorization()
            notificationMessage = status == .denied
                ? "Allow notifications for HabitTracker in iPhone Settings to receive reminders."
                : nil
        } catch {
            notificationMessage = "Notification permission could not be requested. Try again. Your tracking data is saved."
        }
    }

    func openNotification(activityID: UUID) async {
        await open()
        guard snapshot.timeline.activities.contains(where: { $0.id == activityID }) else { return }
        router.showActivity(id: activityID, confirmation: nil)
    }

    private func reload() async throws {
        guard let store else { throw HabitError.storeUnavailable }
        if let snapshotReader { snapshot = try await snapshotReader(store) }
        else { snapshot = try await store.snapshot(at: ClockReading(instant: Date(), timeZone: .current)) }
    }

    @discardableResult
    func apply(_ command: HabitCommand) async -> Bool {
        guard let actions else { errorMessage = HabitError.storeUnavailable.localizedDescription; return false }
        do {
            _ = try await actions.apply(command)
            await refresh()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func log(_ activity: ActivitySnapshot) async {
        guard let actions else { return }
        do {
            _ = try await actions.logNow(activityID: activity.id, source: .app)
            await refresh()
            showConfirmation("Recorded one completion for \(activity.name).")
        } catch { errorMessage = error.localizedDescription }
        failedLogs = await actions.pendingRetries()
    }

    func retry(_ request: LogRequest) async {
        guard let actions else { return }
        do {
            _ = try await actions.retryLog(request)
            await refresh()
            showConfirmation("Completion saved.")
        } catch { errorMessage = error.localizedDescription }
        failedLogs = await actions.pendingRetries()
    }

    func shortcutActivities() async throws -> [ActivitySnapshot] {
        if !isReady { await open() }
        guard isReady else { throw HabitError.storeUnavailable }
        try await reload()
        return snapshot.timeline.activities
    }

    func recordShortcut(activityID: UUID) async throws {
        router.clearConfirmation()
        confirmationTask?.cancel()
        confirmation = nil
        if !isReady { await open() }
        guard isReady, let actions else { throw HabitError.storeUnavailable }
        let receipt = try await actions.logNow(activityID: activityID, source: .shortcut)
        // The receipt proves commit. A refresh problem must not invite another log.
        await refresh()
        if let activity = snapshot.timeline.activities.first(where: { $0.id == activityID }) {
            showConfirmation("Recorded one completion for \(activity.name).")
        }
        router.showActivity(id: activityID, confirmation: receipt)
    }

    private func showConfirmation(_ message: String) {
        confirmationTask?.cancel()
        confirmation = message
        confirmationTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3)) }
            catch { return }
            self?.confirmation = nil
        }
    }

    func currentPeriod(for activity: ActivitySnapshot) -> GoalPeriodSnapshot? {
        let today = try? ClockReading(instant: Date(), timeZone: .current).localDay
        return snapshot.timeline.periods.first {
            $0.activityID == activity.id && today.map($0.range.contains) == true
        }
    }
}

extension HabitError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .validation(field, reason): "Check \(field): \(reason)"
        case .activityUnavailable: "This activity is unavailable. Select an existing activity or create a new one."
        case .completionUnavailable: "This entry is unavailable. Refresh the history and try again."
        case .operationConflict: "This retry differs from the original entry. Refresh before recording a new entry."
        case .storeUnavailable: "Your data could not be opened. Unlock your phone and retry. Existing data is preserved."
        case .saveFailed: "Your change could not be saved. Check available storage and retry."
        }
    }
}
