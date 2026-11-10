import Foundation

actor ActivityActions {
    private let store: HabitStore
    private var failedLogs: [UUID: LogRequest] = [:]

    init(store: HabitStore) { self.store = store }

    func apply(_ command: HabitCommand, at: ClockReading? = nil) async throws -> MutationReceipt {
        try await store.execute(command, at: at ?? ClockReading(instant: Date(), timeZone: .current))
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
