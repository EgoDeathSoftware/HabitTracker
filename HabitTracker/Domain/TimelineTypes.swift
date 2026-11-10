import Foundation

enum PeriodEligibility: String, Sendable {
    case normal
    case initialPartial = "initial_partial"
    case transitional
}

struct ActivitySnapshot: Equatable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var symbolName: String
    let cadence: Cadence
    let createdAt: Date
    let createdDay: CalendarDay
    var trackingStartDay: CalendarDay
    var trackingStartsAtMidnight: Bool
    let initialTarget: Int
    var effectiveTarget: Int
    var pendingTarget: Int?
    var pendingTargetStartDay: CalendarDay?

    init(id: UUID, draft: HabitDraft, at: ClockReading) {
        self.id = id
        name = draft.name
        symbolName = draft.symbolName
        cadence = draft.cadence
        createdAt = at.instant
        createdDay = at.localDay
        trackingStartDay = at.localDay
        trackingStartsAtMidnight = at.instant == at.localDay.midnight(in: at.timeZone)
        initialTarget = draft.target
        effectiveTarget = draft.target
    }
}

struct TargetEdit: Equatable, Sendable {
    let activityID: UUID
    let target: Int
    var addedSlotSeedMinutes: [Int] = []
}

struct CalendarRule: Equatable, Sendable, Identifiable {
    let id: UUID
    let effectiveStartDay: CalendarDay
    let weekStartWeekday: Int
    let createdAt: Date
}

struct PendingCalendarSetting: Equatable, Sendable {
    let weekday: Int
    let effectiveDay: CalendarDay
}

struct TimelineState: Equatable, Sendable {
    var activities: [ActivitySnapshot] = []
    var periods: [GoalPeriodSnapshot] = []
    var calendarRules: [CalendarRule] = []
    var weekStartWeekday = 1
    var pendingCalendarSetting: PendingCalendarSetting?

    var closedPeriods: [GoalPeriodSnapshot] { periods.filter { $0.closedAt != nil } }
}

extension CalendarDay {
    func midnight(in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    var isoWeekday: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let weekday = calendar.component(.weekday, from: midnight(in: TimeZone(secondsFromGMT: 0)!))
        return (weekday + 5) % 7 + 1
    }

    func weekStart(weekday: Int) throws -> CalendarDay {
        try adding(days: -((isoWeekday - weekday + 7) % 7))
    }
}

extension ClockReading {
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID)! }
}
