import Foundation
@testable import HabitTracker

enum FixtureFactory {
    static let activityID = UUID()

    static func period(cadence: Cadence, target: Int) throws -> GoalPeriodSnapshot {
        try GoalPeriodSnapshot(
            activityID: activityID, cadence: cadence,
            range: DayRange(start: CalendarDay("2026-11-09"), end: CalendarDay("2026-11-15")),
            target: target
        )
    }

    static func logs(_ days: [String], activityID: UUID = activityID) throws
        -> [CompletionSnapshot] {
        try days.map {
            try CompletionSnapshot(
                id: UUID(), activityID: activityID, assignedDay: CalendarDay($0),
                occurredAt: nil, captureTimeZoneID: "America/New_York",
                createdAt: Date(timeIntervalSince1970: 0), source: .manual,
                operationID: UUID(), wasTimeOrDateEdited: false
            )
        }
    }
}
