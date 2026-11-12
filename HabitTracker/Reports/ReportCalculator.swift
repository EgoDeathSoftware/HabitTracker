import Foundation

enum ReportSpan: String, CaseIterable, Sendable {
    case week = "Week", month = "Month", year = "Year"
}

struct ReportRequest: Hashable, Sendable {
    let activityID: UUID
    let span: ReportSpan
    let anchor: CalendarDay
}

struct ReportTotal: Sendable {
    var credited = 0
    var target = 0
    var met = 0
    var periods = 0

    var rate: Double? { target > 0 ? Double(credited) / Double(target) : nil }
    var percent: Int? { rate.map { Int(($0 * 100).rounded()) } }

    mutating func include(_ progress: GoalProgress) {
        credited += progress.creditedUnits
        target += progress.target
        met += progress.isMet ? 1 : 0
        periods += 1
    }
}

struct HabitReport: Sendable {
    struct Goal: Sendable {
        let period: GoalPeriodSnapshot
        let progress: GoalProgress
        var eligible: Bool { period.closedAt != nil && period.eligibility == .normal }
    }

    struct Day: Sendable, Identifiable {
        var id: CalendarDay { date }
        let date: CalendarDay
        let count: Int
        let dailyGoal: Goal?
    }

    struct Breakdown: Sendable {
        let range: DayRange
        let total: ReportTotal
    }

    struct Trend: Sendable {
        let previous: DayRange
        let latest: DayRange
        let percentagePoints: Double
    }

    let range: DayRange
    let total: ReportTotal
    let goals: [Goal]
    let days: [Day]
    let breakdown: [Breakdown]
    let trend: Trend?
}

enum ReportCalculator {
    @concurrent static func calculate(snapshot: StoreSnapshot, request: ReportRequest,
                                      at: ClockReading) async throws -> HabitReport {
        try report(snapshot: snapshot, request: request, at: at)
    }

    static func report(snapshot: StoreSnapshot, request: ReportRequest,
                       at: ClockReading) throws -> HabitReport {
        var timeline = snapshot.timeline
        // Weekly goals can have activity-specific initial transition boundaries.
        timeline.periods.removeAll { $0.activityID != request.activityID }
        let range = try bounds(request.span, day: request.anchor, timeline: timeline)
        let counts = snapshot.completions.reduce(into: [CalendarDay: Int]()) { counts, log in
            if log.activityID == request.activityID { counts[log.assignedDay, default: 0] += 1 }
        }
        let history = try timeline.periods.filter { $0.activityID == request.activityID }
            .sorted { $0.range.start < $1.range.start }.map { period in
                try Task.checkCancellation()
                let dailyCounts = try dates(in: period.range).map { counts[$0, default: 0] }
                let raw = dailyCounts.reduce(0, +)
                let units = period.cadence == .daily ? raw : dailyCounts.filter { $0 > 0 }.count
                return HabitReport.Goal(period: period, progress: GoalProgress(
                    rawCount: raw, creditedUnits: min(units, period.target), target: period.target
                ))
            }
        let goals = history.filter { range.contains($0.period.range.end) }
        let dailyGoals = Dictionary(uniqueKeysWithValues: goals.filter { $0.period.cadence == .daily }
            .map { ($0.period.range.start, $0) })
        let days = try dates(in: range).map {
            HabitReport.Day(date: $0, count: counts[$0, default: 0], dailyGoal: dailyGoals[$0])
        }
        return try HabitReport(range: range, total: total(goals), goals: goals, days: days,
            breakdown: breakdown(request.span, range: range, goals: goals, timeline: timeline),
            trend: trend(request.span, range: range, history: history, today: at.localDay,
                         timeline: timeline))
    }

    private static func dates(in range: DayRange) throws -> [CalendarDay] {
        var dates = [range.start]
        while let last = dates.last, last < range.end { dates.append(try last.adding(days: 1)) }
        return dates
    }

    private static func total(_ goals: [HabitReport.Goal]) -> ReportTotal {
        goals.reduce(into: ReportTotal()) { if $1.eligible { $0.include($1.progress) } }
    }

    private static func trend(_ span: ReportSpan, range: DayRange, history: [HabitReport.Goal],
                              today: CalendarDay, timeline: TimelineState) throws -> HabitReport.Trend? {
        let latest = range.end < today ? range : try bounds(
            span, day: min(range.start, try bounds(span, day: today, timeline: timeline).start)
                .adding(days: -1), timeline: timeline
        )
        let previous = try bounds(span, day: latest.start.adding(days: -1), timeline: timeline)
        guard let a = total(history.filter { previous.contains($0.period.range.end) }).rate,
              let b = total(history.filter { latest.contains($0.period.range.end) }).rate else { return nil }
        return HabitReport.Trend(previous: previous, latest: latest, percentagePoints: (b - a) * 100)
    }

    private static func breakdown(_ span: ReportSpan, range: DayRange, goals: [HabitReport.Goal],
                                  timeline: TimelineState) throws -> [HabitReport.Breakdown] {
        guard span != .week else { return [] }
        let interval: ReportSpan = span == .year ? .month : .week
        var start = range.start
        var groups: [HabitReport.Breakdown] = []
        while start <= range.end {
            let full = try bounds(interval, day: start, timeline: timeline)
            let group = try DayRange(start: start, end: min(full.end, range.end))
            groups.append(.init(range: group, total: total(goals.filter {
                group.contains($0.period.range.end)
            })))
            if group.end == range.end { break }
            start = try group.end.adding(days: 1)
        }
        return groups
    }

    private static func bounds(_ span: ReportSpan, day: CalendarDay,
                               timeline: TimelineState) throws -> DayRange {
        switch span {
        case .week:
            if let stored = timeline.periods.first(where: {
                $0.cadence == .weekly && $0.range.contains(day)
            }) { return stored.range }
            let rule = timeline.calendarRules.last { $0.effectiveStartDay <= day }
            let pending = timeline.pendingCalendarSetting
            let weekday = pending.flatMap { $0.effectiveDay <= day ? $0.weekday : nil }
                ?? rule?.weekStartWeekday ?? 1
            let start = try day.weekStart(weekday: weekday)
            let nextChange = timeline.calendarRules.first { $0.effectiveStartDay > day }?.effectiveStartDay
                ?? pending.flatMap { $0.effectiveDay > day ? $0.effectiveDay : nil }
            let end = try start.adding(days: 6)
            return try DayRange(start: start, end: min(end, nextChange?.adding(days: -1) ?? end))
        case .month, .year:
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let interval = calendar.dateInterval(of: span == .month ? .month : .year,
                                                 for: day.midnight(in: calendar.timeZone))!
            let start = try ClockReading(instant: interval.start, timeZone: calendar.timeZone).localDay
            let end = try ClockReading(instant: interval.end.addingTimeInterval(-1),
                                       timeZone: calendar.timeZone).localDay
            return try DayRange(start: start, end: end)
        }
    }
}
