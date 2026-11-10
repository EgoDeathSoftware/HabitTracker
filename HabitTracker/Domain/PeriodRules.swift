import Foundation

enum PeriodRules {
    static func advance(state: TimelineState, at: ClockReading) throws -> TimelineState {
        var value = state
        for index in value.activities.indices {
            try materialize(activityIndex: index, state: &value, at: at)
        }
        if let pending = value.pendingCalendarSetting, pending.effectiveDay <= at.localDay {
            value.weekStartWeekday = pending.weekday
            value.calendarRules.append(CalendarRule(
                id: UUID(), effectiveStartDay: pending.effectiveDay,
                weekStartWeekday: pending.weekday, createdAt: at.instant
            ))
            value.pendingCalendarSetting = nil
        }
        value.periods.sort {
            if $0.activityID == $1.activityID { return $0.range.start < $1.range.start }
            return $0.activityID.uuidString < $1.activityID.uuidString
        }
        return value
    }

    static func editTarget(state: TimelineState, edit: TargetEdit,
                           at: ClockReading) throws -> TimelineState {
        var value = try advance(state: state, at: at)
        guard let index = value.activities.firstIndex(where: { $0.id == edit.activityID }) else {
            throw HabitError.activityUnavailable
        }
        try value.activities[index].cadence.validate(target: edit.target)
        guard let periodIndex = value.periods.firstIndex(where: {
            $0.activityID == edit.activityID && $0.closedAt == nil
        }) else { throw HabitError.validation(field: "date", reason: "No open period is available.") }
        let period = value.periods[periodIndex]
        let current = value.activities[index].effectiveTarget
        value.activities[index].pendingTarget = nil
        value.activities[index].pendingTargetStartDay = nil
        if edit.target == current { return value }
        let appliesNow = period.cadence == .daily || at.instant <= midpoint(period, at: at)
        if appliesNow {
            value.activities[index].effectiveTarget = edit.target
            value.periods[periodIndex].target = edit.target
            value.periods[periodIndex].targetAppliedAt = at.instant
        } else {
            value.activities[index].pendingTarget = edit.target
            value.activities[index].pendingTargetStartDay = period.endDayExclusive
        }
        return value
    }

    static func changeWeekStart(state: TimelineState, weekday: Int,
                                at: ClockReading) throws -> TimelineState {
        guard (1...7).contains(weekday) else {
            throw HabitError.validation(field: "week start", reason: "Choose a weekday.")
        }
        var value = try advance(state: state, at: at)
        // Rollback cannot rewrite a closed week; use the first unclosed week as the anchor.
        let openStarts = value.periods.filter { $0.cadence == .weekly && $0.closedAt == nil }
            .map(\.range.start)
        let anchor = max(at.localDay, openStarts.max() ?? at.localDay)
        let offset = (weekday - anchor.isoWeekday + 7) % 7
        let effective = try anchor.adding(days: offset == 0 ? 7 : offset)
        value.pendingCalendarSetting = PendingCalendarSetting(weekday: weekday, effectiveDay: effective)
        for index in value.periods.indices where value.periods[index].cadence == .weekly
            && value.periods[index].closedAt == nil {
            let start = value.periods[index].range.start
            value.periods[index].range = try DayRange(start: start, end: effective.adding(days: -1))
            value.periods[index].eligibility = try weeklyEligibility(
                activity: value.activities.first { $0.id == value.periods[index].activityID }!,
                start: start, end: effective
            )
        }
        for index in value.activities.indices where value.activities[index].cadence == .weekly
            && value.activities[index].pendingTarget != nil {
            value.activities[index].pendingTargetStartDay = effective
        }
        return value
    }

    static func extendTracking(state: TimelineState, activityID: UUID,
                               to day: CalendarDay) throws -> TimelineState {
        var value = state
        guard let index = value.activities.firstIndex(where: { $0.id == activityID }) else {
            throw HabitError.activityUnavailable
        }
        guard day < value.activities[index].trackingStartDay else { return value }
        value.activities[index].trackingStartDay = day
        value.activities[index].trackingStartsAtMidnight = true
        let activity = value.activities[index]
        let existing = value.periods.filter { $0.activityID == activityID }
        let firstStart = existing.map(\.range.start).min()!
        let weekday = value.calendarRules.first?.weekStartWeekday ?? 1
        var start = activity.cadence == .daily ? day : try day.weekStart(weekday: weekday)
        while start < firstStart {
            let end = min(try start.adding(days: activity.cadence == .daily ? 1 : 7), firstStart)
            var period = try makePeriod(activity: activity, start: start, end: end,
                                        target: activity.initialTarget)
            period.closedAt = existing.first?.closedAt ?? activity.createdAt
            value.periods.append(period)
            start = end
        }
        for periodIndex in value.periods.indices where value.periods[periodIndex].activityID == activityID
            && value.periods[periodIndex].eligibility == .initialPartial {
            let period = value.periods[periodIndex]
            value.periods[periodIndex].eligibility = activity.cadence == .daily ? .normal
                : try weeklyEligibility(
                    activity: activity, start: period.range.start, end: period.endDayExclusive
                )
        }
        value.periods.sort { $0.range.start < $1.range.start }
        return value
    }

    private static func materialize(activityIndex: Int, state: inout TimelineState,
                                    at: ClockReading) throws {
        var activity = state.activities[activityIndex]
        let existing = state.periods.filter { $0.activityID == activity.id }
        let last = existing.max { $0.range.start < $1.range.start }
        var start: CalendarDay
        if let last { start = last.endDayExclusive }
        else {
            let weekday = state.calendarRules.last(where: {
                $0.effectiveStartDay <= activity.trackingStartDay
            })?.weekStartWeekday ?? state.weekStartWeekday
            start = activity.cadence == .daily ? activity.trackingStartDay
                : try activity.trackingStartDay.weekStart(weekday: weekday)
        }
        while start <= at.localDay {
            if let pending = activity.pendingTarget, let day = activity.pendingTargetStartDay,
               day <= start {
                activity.effectiveTarget = pending
                activity.pendingTarget = nil
                activity.pendingTargetStartDay = nil
            }
            var end = try start.adding(days: activity.cadence == .daily ? 1 : 7)
            if activity.cadence == .weekly, let pending = state.pendingCalendarSetting,
               pending.effectiveDay > start, pending.effectiveDay < end {
                end = pending.effectiveDay
            }
            state.periods.append(try makePeriod(
                activity: activity, start: start, end: end, target: activity.effectiveTarget
            ))
            start = end
        }
        for index in state.periods.indices where state.periods[index].activityID == activity.id
            && state.periods[index].closedAt == nil
            && state.periods[index].endDayExclusive <= at.localDay {
            state.periods[index].closedAt = at.instant
        }
        state.activities[activityIndex] = activity
    }

    private static func makePeriod(activity: ActivitySnapshot, start: CalendarDay,
                                   end: CalendarDay, target: Int) throws -> GoalPeriodSnapshot {
        var period = try GoalPeriodSnapshot(
            activityID: activity.id, cadence: activity.cadence,
            range: DayRange(start: start, end: end.adding(days: -1)), target: target
        )
        period.targetAppliedAt = activity.createdAt
        if activity.cadence == .weekly {
            period.eligibility = try weeklyEligibility(activity: activity, start: start, end: end)
        } else if start == activity.trackingStartDay && !activity.trackingStartsAtMidnight {
            period.eligibility = .initialPartial
        }
        return period
    }

    private static func weeklyEligibility(activity: ActivitySnapshot, start: CalendarDay,
                                          end: CalendarDay) throws -> PeriodEligibility {
        if try start.adding(days: 7) != end { return .transitional }
        if start < activity.trackingStartDay
            || (start == activity.trackingStartDay && !activity.trackingStartsAtMidnight) {
            return .initialPartial
        }
        return .normal
    }

    private static func midpoint(_ period: GoalPeriodSnapshot, at: ClockReading) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = at.timeZone
        let start = period.range.start.midnight(in: at.timeZone)
        if period.eligibility != .transitional {
            let day = calendar.date(byAdding: .day, value: 3, to: start)!
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        }
        // Interpret transition coordinates in a fixed zone before converting back to local time.
        let utc = TimeZone(secondsFromGMT: 0)!
        let low = period.range.start.midnight(in: utc)
        let high = period.endDayExclusive.midnight(in: utc)
        var wallCalendar = Calendar(identifier: .gregorian)
        wallCalendar.timeZone = utc
        let components = wallCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: low.addingTimeInterval(high.timeIntervalSince(low) / 2)
        )
        return calendar.date(from: components)!
    }
}
