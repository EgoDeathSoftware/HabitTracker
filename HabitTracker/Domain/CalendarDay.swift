import Foundation

/// A Gregorian date, independent of travel and timezone changes.
struct CalendarDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init(_ value: String) throws {
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.map(\.count) == [4, 2, 2],
              value.utf8.allSatisfy({ (48...57).contains($0) || $0 == 45 }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            throw HabitError.validation(field: "date", reason: "Use YYYY-MM-DD.")
        }
        try self.init(year: year, month: month, day: day)
    }

    init(year: Int, month: Int, day: Int) throws {
        let calendar = Self.calendar
        let components = DateComponents(year: year, month: month, day: day)
        guard (1...9999).contains(year), let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components else {
            throw HabitError.validation(field: "date", reason: "Choose a valid Gregorian date.")
        }
        self.year = year
        self.month = month
        self.day = day
    }

    var description: String { String(format: "%04d-%02d-%02d", year, month, day) }

    static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    func adding(days: Int) throws -> CalendarDay {
        let calendar = Self.calendar
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              let result = calendar.date(byAdding: .day, value: days, to: date) else {
            throw HabitError.validation(field: "date", reason: "Date is outside the supported range.")
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: result)
        return try CalendarDay(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

struct DayRange: Equatable, Sendable {
    let start: CalendarDay
    let end: CalendarDay

    init(start: CalendarDay, end: CalendarDay) throws {
        guard start <= end else {
            throw HabitError.validation(field: "date range", reason: "End must follow start.")
        }
        self.start = start
        self.end = end
    }

    func contains(_ day: CalendarDay) -> Bool { start <= day && day <= end }
}

struct ClockReading: Equatable, Sendable {
    let instant: Date
    let timeZoneID: String
    let localDay: CalendarDay
    let localMinute: Int

    init(instant: Date, timeZone: TimeZone) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: instant)
        self.instant = instant
        timeZoneID = timeZone.identifier
        localDay = try CalendarDay(year: parts.year!, month: parts.month!, day: parts.day!)
        localMinute = parts.hour! * 60 + parts.minute!
    }
}
