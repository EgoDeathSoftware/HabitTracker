import Foundation

enum ScheduleOutcome: Equatable, Sendable {
    case scheduled, permissionRequired, failed
}

actor NotificationScheduler {
    private let client: any NotificationClient
    private let snapshot: @Sendable () async throws -> StoreSnapshot
    private let clock: @Sendable () throws -> ClockReading
    private var generation = 0
    private var worker: Task<ScheduleOutcome, Never>?

    init(client: any NotificationClient,
         snapshot: @escaping @Sendable () async throws -> StoreSnapshot,
         clock: @escaping @Sendable () throws -> ClockReading = {
             try ClockReading(instant: Date(), timeZone: .current)
         }) {
        self.client = client
        self.snapshot = snapshot
        self.clock = clock
    }

    func reconcile() async -> ScheduleOutcome {
        generation += 1
        if let worker { return await worker.value }
        let task = Task { await self.run() }
        worker = task
        return await task.value
    }

    private func run() async -> ScheduleOutcome {
        while true {
            let requested = generation
            let result = await replaceQueue()
            if requested == generation {
                worker = nil
                return result
            }
        }
    }

    private func replaceQueue() async -> ScheduleOutcome {
        do {
            let state = try await snapshot()
            let now = try clock()
            let authorization = await client.authorization()
            let allowed = authorization == .authorized || authorization == .provisional
            let plan = allowed ? NotificationPlanner.plan(snapshot: state, at: now) : []
            let pending = await client.pendingIDs().filter { $0.hasPrefix("habit.") }
            let desired = Set(plan.map(\.id))
            await client.remove(ids: pending.subtracting(desired))
            // Re-add matching identifiers as well so renamed activity titles are refreshed.
            var failed = false
            for request in plan {
                do { try await client.add(request) }
                catch { failed = true }
            }
            // Store reads also advance periods. A changed revision invalidates this projection.
            if try await snapshot().revision != state.revision { generation += 1 }
            if !allowed { return .permissionRequired }
            return failed ? .failed : .scheduled
        } catch { return .failed }
    }
}
