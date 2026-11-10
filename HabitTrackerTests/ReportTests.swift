import Foundation
import Testing
@testable import HabitTracker

struct ReportTests {
    @Test func eligiblePeriodsAndWeightedRate() throws {
        let id = UUID()
        let days = try ["2026-11-01", "2026-11-02", "2026-11-03", "2026-11-04"]
            .map(CalendarDay.init)
        var periods = try zip(days, [1, 3, 1, 1]).map { day, target in
            try GoalPeriodSnapshot(activityID: id, cadence: .daily,
                                   range: DayRange(start: day, end: day), target: target)
        }
        let now = try clock("2026-11-04")
        for index in 0..<3 { periods[index].closedAt = now.instant }
        periods[2].eligibility = .initialPartial
        let logs = [days[0], days[0], days[1], days[1], days[3]].map { completion(id, $0) }
        let snapshot = StoreSnapshot(timeline: TimelineState(periods: periods), completions: logs)
        let report = try ReportCalculator.report(snapshot: snapshot,
            request: ReportRequest(activityID: id, span: .month, anchor: now.localDay), at: now)
        #expect(report.total.credited == 3)
        #expect(report.total.target == 4)
        #expect(report.total.percent == 75)
        #expect(report.total.met == 1)
        #expect(report.total.periods == 2)
        #expect(report.goals.count == 4)
        #expect(report.days.first?.count == 2)
    }

    @Test func crossMonthAndYear() throws {
        let id = UUID()
        let now = try clock("2027-01-05")
        let periods = try [("2026-11-30", "2026-12-06"), ("2026-12-28", "2027-01-03")]
            .map { start, end in
                var period = try GoalPeriodSnapshot(activityID: id, cadence: .weekly,
                    range: DayRange(start: CalendarDay(start), end: CalendarDay(end)), target: 2)
                period.closedAt = now.instant
                return period
            }
        let snapshot = StoreSnapshot(timeline: TimelineState(periods: periods), completions: [
            completion(id, try CalendarDay("2026-11-30"))
        ])
        func report(_ span: ReportSpan, _ day: String) throws -> HabitReport {
            try ReportCalculator.report(snapshot: snapshot,
                request: ReportRequest(activityID: id, span: span, anchor: CalendarDay(day)), at: now)
        }
        let november = try report(.month, "2026-11-30")
        #expect(november.goals.isEmpty)
        #expect(november.total.percent == nil)
        #expect(november.days.last?.count == 1)
        #expect(november.days.allSatisfy { $0.dailyGoal == nil })
        #expect(try report(.month, "2026-12-01").goals.first?.progress.creditedUnits == 1)
        #expect(try report(.year, "2026-01-01").goals.count == 1)
        #expect(try report(.year, "2027-01-01").goals.count == 1)
    }

    @Test func completedPeriodComparisons() throws {
        let id = UUID()
        let now = try clock("2026-11-10")
        let days = try ["2026-09-01", "2026-10-01", "2026-11-01"].map(CalendarDay.init)
        let periods = try days.map { day in
            var period = try GoalPeriodSnapshot(activityID: id, cadence: .daily,
                range: DayRange(start: day, end: day), target: 1)
            period.closedAt = now.instant
            return period
        }
        let report = try ReportCalculator.report(snapshot: StoreSnapshot(
            timeline: TimelineState(periods: periods), completions: [completion(id, days[1])]),
            request: ReportRequest(activityID: id, span: .month, anchor: now.localDay), at: now)
        #expect(report.total.percent == 0)
        #expect(report.trend?.previous.start == days[0])
        #expect(report.trend?.latest.start == days[1])
        #expect(report.trend?.percentagePoints == 100)
    }

    @Test func tenYearHistoryWithTwentyFiveHabits() throws {
        let ids = (0..<25).map { _ in UUID() }
        let start = try CalendarDay("2016-01-01")
        let now = try clock("2026-01-01")
        let ranges = try (0..<3653).map { offset in
            let day = try start.adding(days: offset)
            return try DayRange(start: day, end: day)
        }
        let periods = try ids.flatMap { id in
            try ranges.map { range in
                var period = try GoalPeriodSnapshot(activityID: id, cadence: .daily,
                                                    range: range, target: 1)
                period.closedAt = now.instant
                return period
            }
        }
        let id = ids[0]
        let snapshot = StoreSnapshot(timeline: TimelineState(periods: periods), completions: [
            completion(id, try CalendarDay("2025-01-01")),
            completion(ids[1], try CalendarDay("2025-01-02"))
        ])
        let request = try ReportRequest(activityID: id, span: .year, anchor: CalendarDay("2025-06-01"))
        let clock = ContinuousClock()
        let startTime = clock.now
        let report = try ReportCalculator.report(snapshot: snapshot, request: request, at: now)
        print("Ten-year report calculation: \(startTime.duration(to: clock.now))")
        #expect(report.total.target == 365)
        #expect(report.total.credited == 1)
        #expect(report.breakdown.count == 12)
        #expect(report.days.count == 365)
    }

    private func clock(_ day: String) throws -> ClockReading {
        let zone = TimeZone(secondsFromGMT: 0)!
        return try ClockReading(instant: CalendarDay(day).midnight(in: zone), timeZone: zone)
    }

    private func completion(_ id: UUID, _ day: CalendarDay) -> CompletionSnapshot {
        CompletionSnapshot(id: UUID(), activityID: id, assignedDay: day, occurredAt: nil,
                           captureTimeZoneID: "GMT", createdAt: .distantPast, source: .manual,
                           operationID: UUID(), wasTimeOrDateEdited: false)
    }
}
