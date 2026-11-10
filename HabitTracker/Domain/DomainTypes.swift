import Foundation

enum HabitError: Error, Equatable, Sendable {
    case validation(field: String, reason: String)
    case activityUnavailable
    case completionUnavailable
    case operationConflict
    case storeUnavailable
    case saveFailed
}

enum Cadence: String, Sendable, Codable {
    case daily, weekly

    func validate(target: Int) throws {
        let maximum = self == .daily ? 10 : 7
        guard (1...maximum).contains(target) else {
            throw HabitError.validation(field: "target", reason: "Choose a target from 1 to \(maximum).")
        }
    }
}

struct HabitDraft: Equatable, Sendable {
    let name: String
    let symbolName: String
    let cadence: Cadence
    let target: Int

    init(name: String, symbolName: String, cadence: Cadence, target: Int) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HabitError.validation(field: "name", reason: "Enter an activity name.")
        }
        try cadence.validate(target: target)
        self.name = name
        self.symbolName = symbolName
        self.cadence = cadence
        self.target = target
    }
}

enum CompletionSource: String, Sendable, Codable {
    case app, shortcut, manual
}

struct CompletionSnapshot: Equatable, Sendable, Identifiable {
    let id: UUID
    let activityID: UUID
    let assignedDay: CalendarDay
    let occurredAt: Date?
    let captureTimeZoneID: String
    let createdAt: Date
    let source: CompletionSource
    let operationID: UUID
    let wasTimeOrDateEdited: Bool
}

struct GoalPeriodSnapshot: Equatable, Sendable {
    let activityID: UUID
    let cadence: Cadence
    var range: DayRange
    var target: Int
    var eligibility: PeriodEligibility = .normal
    var closedAt: Date?
    var targetAppliedAt: Date = .distantPast

    var endDayExclusive: CalendarDay { try! range.end.adding(days: 1) }

    init(activityID: UUID, cadence: Cadence, range: DayRange, target: Int) throws {
        try cadence.validate(target: target)
        self.activityID = activityID
        self.cadence = cadence
        self.range = range
        self.target = target
    }
}

struct GoalProgress: Equatable, Sendable {
    let rawCount: Int
    let creditedUnits: Int
    let target: Int

    var isMet: Bool { creditedUnits >= target }
    var fraction: Double { Double(creditedUnits) / Double(target) }
}
