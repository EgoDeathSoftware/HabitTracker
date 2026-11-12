import Foundation

actor ActivityActions {
    private let store: HabitStore
    private let scheduler: NotificationScheduler?
    private var failedLogs: [UUID: LogRequest] = [:]

    init(store: HabitStore, scheduler: NotificationScheduler? = nil) {
        self.store = store
        self.scheduler = scheduler
    }

    func apply(_ command: HabitCommand, at: ClockReading? = nil) async throws -> MutationReceipt {
        let receipt = try await store.execute(command, at: at ?? ClockReading(instant: Date(), timeZone: .current))
        if let scheduler { _ = await scheduler.reconcile() }
        return receipt
    }

    func logNow(activityID: UUID, source: CompletionSource) async throws -> MutationReceipt {
        let now = try ClockReading(instant: Date(), timeZone: .current)
        let request = LogRequest(
            activityID: activityID, operationID: UUID(), assignedDay: now.localDay,
            occurredAt: now.instant, captureTimeZoneID: now.timeZoneID, source: source
        )
        return try await retryLog(request, at: now)
    }

    func retryLog(_ request: LogRequest, at: ClockReading? = nil) async throws -> MutationReceipt {
        do {
            let receipt = try await apply(.log(request), at: at)
            failedLogs.removeValue(forKey: request.operationID)
            return receipt
        } catch {
            failedLogs[request.operationID] = request
            throw error
        }
    }

    func pendingRetries() -> [LogRequest] { Array(failedLogs.values) }
}
