import Foundation

struct ReminderSlot: Equatable, Sendable {
    let seedMinute: Int
    var effectiveMinute: Int
    var lastAdjustedDay: CalendarDay?

    init(minute: Int) {
        seedMinute = minute
        effectiveMinute = minute
    }
}

struct ReminderConfiguration: Equatable, Sendable {
    let activityID: UUID
    var isEnabled: Bool
    var target: Int
    var learningStartedAt: Date
    var learningStartDay: CalendarDay
    var slots: [ReminderSlot]
    var pendingSeeds: [Int] = []
}

struct ReminderChange: Equatable, Sendable {
    let slotIndex: Int
    let oldMinute: Int
    let newMinute: Int
}

struct AdjustmentNotice: Equatable, Sendable, Identifiable {
    let id: UUID
    let activityID: UUID
    let createdAt: Date
    let reason: String
    let changes: [ReminderChange]
    var acknowledgedAt: Date?
}

struct LearningDecision: Equatable, Sendable {
    let activityID: UUID
    let qualifyingDateCount: Int
    let changes: [ReminderChange]
}

enum ReminderLearning {
    static func evaluate(snapshot: StoreSnapshot, at: ClockReading) -> [LearningDecision] {
        let logs = Dictionary(grouping: snapshot.completions, by: \.activityID)
        return snapshot.timeline.activities.compactMap { activity in
            guard let configuration = snapshot.reminders[activity.id], configuration.isEnabled,
                  configuration.target == activity.effectiveTarget else { return nil }
            return evaluate(configuration, cadence: activity.cadence,
                            logs: logs[activity.id, default: []], at: at)
        }
    }

    static func apply(to snapshot: inout StoreSnapshot, at: ClockReading) {
        for decision in evaluate(snapshot: snapshot, at: at) where !decision.changes.isEmpty {
            for change in decision.changes {
                snapshot.reminders[decision.activityID]?.slots[change.slotIndex].effectiveMinute =
                    change.newMinute
                snapshot.reminders[decision.activityID]?.slots[change.slotIndex].lastAdjustedDay =
                    at.localDay
            }
            snapshot.notices.append(AdjustmentNotice(
                id: UUID(), activityID: decision.activityID, createdAt: at.instant,
                reason: "Adjusted to match recent completion times.", changes: decision.changes
            ))
        }
    }

    static func validMinutes(_ minutes: [Int]) -> Bool {
        guard minutes.allSatisfy({ (0..<1440).contains($0) }) else { return false }
        guard let first = minutes.first, let last = minutes.last else { return false }
        return zip(minutes, minutes.dropFirst()).allSatisfy { $1 - $0 >= 30 }
            && 1440 + first - last >= 30
    }

    private static func evaluate(_ configuration: ReminderConfiguration, cadence: Cadence,
                                 logs: [CompletionSnapshot], at: ClockReading) -> LearningDecision {
        let slotCount = cadence == .weekly ? 1 : configuration.target
        let dates = samples(configuration, cadence: cadence, logs: logs, at: at)
        var changes: [ReminderChange] = []
        var minutes = configuration.slots.map(\.effectiveMinute)
        if dates.count >= 5, minutes.count == slotCount {
            for (index, slot) in configuration.slots.enumerated() {
                if let last = slot.lastAdjustedDay, last >= at.localDay { continue }
                let median = circularMedian(dates.map { $0[index] }, near: slot.effectiveMinute)
                let rounded = ((median + 2) / 5 * 5) % 1440
                let delta = ((rounded - slot.effectiveMinute + 2160) % 1440) - 720
                guard abs(delta) >= 15 else { continue }
                let proposed = (slot.effectiveMinute + min(30, max(-30, delta)) + 1440) % 1440
                minutes[index] = proposed
                if validMinutes(minutes + configuration.pendingSeeds) {
                    changes.append(.init(slotIndex: index, oldMinute: slot.effectiveMinute,
                                         newMinute: proposed))
                } else { minutes[index] = slot.effectiveMinute }
            }
        }
        return LearningDecision(activityID: configuration.activityID,
                                qualifyingDateCount: dates.count, changes: changes)
    }

    private static func samples(_ configuration: ReminderConfiguration, cadence: Cadence,
                                logs: [CompletionSnapshot], at: ClockReading) -> [[Int]] {
        let span = cadence == .weekly ? 56 : 28
        let start = (try? at.localDay.adding(days: -span)) ?? configuration.learningStartDay
        let count = cadence == .weekly ? 1 : configuration.target
        let eligible = logs.filter { log in
            guard log.source != .manual, !log.wasTimeOrDateEdited, let date = log.occurredAt else {
                return false
            }
            return date >= configuration.learningStartedAt && date < at.instant
                && log.assignedDay >= max(start, configuration.learningStartDay)
                && log.assignedDay < at.localDay
        }
        return Dictionary(grouping: eligible, by: \.assignedDay).values.compactMap { day in
            let minutes = day.sorted {
                ($0.occurredAt!, $0.id.uuidString) < ($1.occurredAt!, $1.id.uuidString)
            }.prefix(count).compactMap { log -> Int? in
                guard let zone = TimeZone(identifier: log.captureTimeZoneID),
                      let date = log.occurredAt else { return nil }
                return try? ClockReading(instant: date, timeZone: zone).localMinute
            }
            return minutes.count == count ? minutes : nil
        }
    }

    static func circularMedian(_ samples: [Int], near current: Int) -> Int {
        func distance(_ a: Int, _ b: Int) -> Int { min(abs(a - b), 1440 - abs(a - b)) }
        var best = (cost: Int.max, movement: Int.max, minute: current)
        for minute in 0..<1440 {
            let cost = samples.reduce(0) { $0 + distance($1, minute) }
            let candidate = (cost, distance(current, minute), minute)
            if candidate < best { best = candidate }
        }
        return best.minute
    }
}
