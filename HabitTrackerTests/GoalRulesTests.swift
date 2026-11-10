import Foundation
import Testing
@testable import HabitTracker

struct GoalRulesTests {
    // Removing the daily cap or counting weekly repetitions as days must fail these tests.
    @Test func dailyCredit() throws {
        let logs = try FixtureFactory.logs(["2026-11-09", "2026-11-09"])
        let one = GoalRules.progress(period: try dailyPeriod(1), completions: logs)
        #expect(one.rawCount == 2 && one.creditedUnits == 1 && one.isMet)
        let partial = GoalRules.progress(period: try dailyPeriod(2), completions: [logs[0]])
        #expect(partial.creditedUnits == 1 && partial.target == 2 && !partial.isMet)
        let surplus = GoalRules.progress(
            period: try dailyPeriod(2), completions: logs + [logs[0]]
        )
        #expect(surplus.creditedUnits == 2 && surplus.fraction == 1)
    }

    @Test func weeklyDistinctDays() throws {
        let period = try FixtureFactory.period(cadence: .weekly, target: 2)
        let monday = try FixtureFactory.logs(["2026-11-09", "2026-11-09"])
        let first = GoalRules.progress(period: period, completions: monday)
        #expect(first.rawCount == 2 && first.creditedUnits == 1 && !first.isMet)
        let both = GoalRules.progress(
            period: period,
            completions: monday + (try FixtureFactory.logs(["2026-11-10"]))
        )
        #expect(both.rawCount == 3 && both.creditedUnits == 2 && both.isMet)
    }

    @Test func ignoresOtherActivitiesAndOutsideDates() throws {
        let logs = try FixtureFactory.logs(["2026-11-08", "2026-11-16"])
            + FixtureFactory.logs(["2026-11-09"], activityID: UUID())
        let result = GoalRules.progress(
            period: try FixtureFactory.period(cadence: .weekly, target: 2), completions: logs
        )
        #expect(result.rawCount == 0 && result.creditedUnits == 0 && !result.isMet)
    }

    @Test func validatesGregorianDates() throws {
        for value in ["2026-02-29", "2026-04-31", "2026-00-01", "2026-13-01",
                      "2026-01-00", "2026-1-01", "0000-01-01", "bad"] {
            #expect(throws: HabitError.self) { try CalendarDay(value) }
        }
        let leap = try CalendarDay("2028-02-29")
        #expect(leap.description == "2028-02-29")
        #expect(try leap.adding(days: 1).description == "2028-03-01")
        #expect(try CalendarDay("2026-12-31").adding(days: 1).description == "2027-01-01")
        #expect(throws: HabitError.self) {
            try DayRange(start: CalendarDay("2026-11-10"), end: CalendarDay("2026-11-09"))
        }
    }

    @Test func validatesDraftsWithoutRequiringUniqueNames() throws {
        for (cadence, targets) in [(Cadence.daily, [0, 11]), (.weekly, [0, 8])] {
            for target in targets {
                #expect(throws: HabitError.self) {
                    try HabitDraft(name: "Read", symbolName: "book", cadence: cadence, target: target)
                }
            }
        }
        #expect(throws: HabitError.self) {
            try HabitDraft(name: " \n", symbolName: "book", cadence: .daily, target: 1)
        }
        let first = try HabitDraft(name: "読書 📚", symbolName: "book", cadence: .daily, target: 10)
        let second = try HabitDraft(name: first.name, symbolName: "book", cadence: .weekly, target: 7)
        #expect(first.name == second.name && first.name == "読書 📚")
    }

    private func dailyPeriod(_ target: Int) throws -> GoalPeriodSnapshot {
        try GoalPeriodSnapshot(
            activityID: FixtureFactory.activityID, cadence: .daily,
            range: DayRange(start: CalendarDay("2026-11-09"), end: CalendarDay("2026-11-09")),
            target: target
        )
    }
}
