import Foundation

struct ReminderEdit: Sendable {
    let activityID: UUID
    let isEnabled: Bool
    let minutes: [Int]
}

enum ReminderRules {
    static func advance(_ snapshot: inout StoreSnapshot, at: ClockReading) throws {
        let previous = snapshot.timeline.activities
        snapshot.timeline = try PeriodRules.advance(state: snapshot.timeline, at: at)
        for activity in snapshot.timeline.activities {
            guard var config = snapshot.reminders[activity.id],
                  activity.effectiveTarget != config.target else { continue }
            let activationDay = previous.first { $0.id == activity.id }?.pendingTargetStartDay
                ?? at.localDay
            let activation = activationDay.midnight(in: at.timeZone)
            let minutes = try adjustedMinutes(config, activity: activity,
                                              target: activity.effectiveTarget,
                                              seeds: config.pendingSeeds)
            reset(&config, target: activity.effectiveTarget, minutes: minutes,
                  at: activation, day: activationDay)
            snapshot.reminders[activity.id] = config
        }
    }

    static func edit(_ edit: ReminderEdit, in snapshot: inout StoreSnapshot,
                     at: ClockReading) throws {
        guard let activity = snapshot.timeline.activities.first(where: { $0.id == edit.activityID })
        else { throw HabitError.activityUnavailable }
        if !edit.isEnabled {
            snapshot.reminders[activity.id]?.isEnabled = false
            return
        }
        let count = activity.cadence == .daily ? activity.effectiveTarget : 1
        try validate(edit.minutes, count: count)
        let old = snapshot.reminders[activity.id]
        if old?.isEnabled == true, old?.slots.map(\.effectiveMinute) == edit.minutes { return }
        let pending = old?.pendingSeeds ?? []
        if let target = activity.pendingTarget, target > count, activity.cadence == .daily {
            try validate(edit.minutes + pending, count: target)
        }
        let epoch = try learningEpoch(activity, in: snapshot.timeline, at: at)
        var config = ReminderConfiguration(
            activityID: activity.id, isEnabled: true, target: activity.effectiveTarget,
            learningStartedAt: old?.learningStartedAt ?? epoch.instant,
            learningStartDay: old?.learningStartDay ?? epoch.day,
            slots: edit.minutes.map(ReminderSlot.init), pendingSeeds: pending
        )
        for index in config.slots.indices where index < (old?.slots.count ?? 0) {
            config.slots[index].lastAdjustedDay = old?.slots[index].lastAdjustedDay
        }
        snapshot.reminders[activity.id] = config
    }

    private static func learningEpoch(_ activity: ActivitySnapshot, in timeline: TimelineState,
                                      at: ClockReading) throws -> (instant: Date, day: CalendarDay) {
        let periods = timeline.periods.filter { $0.activityID == activity.id }
            .sorted { $0.range.start > $1.range.start }
        let active = periods.prefix { $0.target == activity.effectiveTarget }
        var start = max(activity.createdAt, active.map(\.targetAppliedAt).max() ?? activity.createdAt)
        var day = start == activity.createdAt ? activity.createdDay
            : try ClockReading(instant: start, timeZone: at.timeZone).localDay
        if active.count < periods.count, let first = active.last {
            start = max(start, first.range.start.midnight(in: at.timeZone))
            day = max(day, first.range.start)
        }
        return (start, day)
    }

    static func targetChanged(_ edit: TargetEdit, activity: ActivitySnapshot,
                              snapshot: inout StoreSnapshot, at: ClockReading) throws {
        guard var config = snapshot.reminders[activity.id] else { return }
        let target = activity.pendingTarget ?? activity.effectiveTarget
        let minutes = try adjustedMinutes(config, activity: activity, target: target,
                                          seeds: edit.addedSlotSeedMinutes)
        if activity.pendingTarget != nil {
            config.pendingSeeds = edit.addedSlotSeedMinutes
        } else if activity.effectiveTarget != config.target {
            let periodStart = snapshot.timeline.periods.first {
                $0.activityID == activity.id && $0.closedAt == nil
            }?.range.start ?? at.localDay
            let startDay = max(at.localDay, periodStart)
            let start = max(at.instant, startDay.midnight(in: at.timeZone))
            reset(&config, target: target, minutes: minutes, at: start, day: startDay)
        } else { config.pendingSeeds = [] }
        snapshot.reminders[activity.id] = config
    }

    private static func adjustedMinutes(_ config: ReminderConfiguration, activity: ActivitySnapshot,
                                        target: Int, seeds: [Int]) throws -> [Int] {
        let count = activity.cadence == .daily ? target : 1
        let minutes = Array(config.slots.map(\.effectiveMinute).prefix(count))
        if !config.isEnabled { return minutes }
        let proposed = minutes + Array(seeds.prefix(max(0, count - minutes.count)))
        try validate(proposed, count: count)
        return proposed
    }

    private static func validate(_ minutes: [Int], count: Int) throws {
        guard minutes.count == count, ReminderLearning.validMinutes(minutes) else {
            throw HabitError.validation(field: "reminder times",
                reason: "Choose \(count) ordered times at least 30 minutes apart, including across midnight.")
        }
    }

    private static func reset(_ config: inout ReminderConfiguration, target: Int, minutes: [Int],
                              at: Date, day: CalendarDay) {
        let old = config.slots
        config.target = target
        config.learningStartedAt = at
        config.learningStartDay = day
        config.pendingSeeds = []
        config.slots = minutes.enumerated().map { index, minute in
            var slot = ReminderSlot(minute: minute)
            if index < old.count { slot.lastAdjustedDay = old[index].lastAdjustedDay }
            return slot
        }
    }
}
