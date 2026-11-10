import Foundation
import Testing
@testable import HabitTracker

struct PeriodRulesTests {
    private func clock(_ text: String, zone: String = "America/New_York") throws -> ClockReading {
        let formatter = ISO8601DateFormatter()
        return try ClockReading(instant: formatter.date(from: text)!, timeZone: TimeZone(identifier: zone)!)
    }

    private func state(_ cadence: Cadence = .weekly,
                       created: String = "2026-11-09T05:00:00Z") throws -> TimelineState {
        let now = try clock(created)
        let activity = try ActivitySnapshot(id: UUID(), draft: HabitDraft(
            name: "Read", symbolName: "book", cadence: cadence, target: 2
        ), at: now)
        return try PeriodRules.advance(state: TimelineState(activities: [activity]), at: now)
    }

    @Test func weeklyMidpoint() throws {
        let initial = try state()
        let edit = TargetEdit(activityID: initial.activities[0].id, target: 4)
        let exact = try PeriodRules.editTarget(
            state: initial, edit: edit, at: clock("2026-11-12T17:00:00Z")
        )
        #expect(exact.activities[0].effectiveTarget == 4)
        let late = try PeriodRules.editTarget(
            state: initial, edit: edit, at: clock("2026-11-12T17:00:01Z")
        )
        #expect(late.activities[0].effectiveTarget == 2)
        #expect(late.activities[0].pendingTarget == 4)
        #expect(late.activities[0].pendingTargetStartDay?.description == "2026-11-16")
    }

    @Test func pendingReplacementAndActivation() throws {
        var value = try state()
        let id = value.activities[0].id
        let late = try clock("2026-11-13T17:00:00Z")
        for target in [4, 5] {
            value = try PeriodRules.editTarget(
                state: value, edit: TargetEdit(activityID: id, target: target), at: late
            )
        }
        #expect(value.activities[0].pendingTarget == 5)
        let cancelled = try PeriodRules.editTarget(
            state: value, edit: TargetEdit(activityID: id, target: 2), at: late
        )
        #expect(cancelled.activities[0].pendingTarget == nil)
        value = try PeriodRules.advance(state: value, at: try clock("2026-11-24T17:00:00Z"))
        #expect(value.activities[0].effectiveTarget == 5)
        #expect(value.activities[0].pendingTarget == nil)
        #expect(value.periods.map(\.target) == [2, 5, 5])
    }

    @Test func materializeEmptyGap() throws {
        let initial = try state(.daily, created: "2026-01-01T05:00:00Z")
        let value = try PeriodRules.advance(state: initial, at: try clock("2026-02-01T17:00:00Z"))
        #expect(value.periods.count == 32)
        #expect(value.closedPeriods.count == 31)
        #expect(value.periods.allSatisfy { $0.eligibility == .normal })
        let partial = try state(.daily, created: "2026-01-01T17:00:00Z")
        #expect(partial.periods[0].eligibility == .initialPartial)
    }

    @Test func calendarEdges() throws {
        let initial = try state()
        var value = try PeriodRules.changeWeekStart(
            state: initial, weekday: 7, at: clock("2026-11-10T17:00:00Z")
        )
        #expect(value.periods[0].endDayExclusive.description == "2026-11-15")
        #expect(value.periods[0].eligibility == .transitional)
        value = try PeriodRules.advance(state: value, at: try clock("2026-11-15T05:00:00Z"))
        #expect(value.closedPeriods.count == 1)
        #expect(value.periods[1].range.start.description == "2026-11-15")
        #expect(value.weekStartWeekday == 7)
        let leap = try state(.daily, created: "2028-02-28T05:00:00Z")
        let marched = try PeriodRules.advance(state: leap, at: try clock("2028-03-01T05:00:00Z"))
        #expect(marched.periods.count == 3 && marched.closedPeriods.count == 2)
    }

    @Test func closedPeriodRollback() throws {
        let initial = try state()
        let advanced = try PeriodRules.advance(state: initial, at: try clock("2026-11-17T17:00:00Z"))
        let value = try PeriodRules.editTarget(
            state: advanced, edit: TargetEdit(activityID: initial.activities[0].id, target: 4),
            at: clock("2026-11-10T17:00:00Z")
        )
        #expect(value.periods[0].target == 2 && value.periods[0].closedAt != nil)
        #expect(value.periods[1].target == 4)
        #expect(value.periods.count == 2)
        #expect(Set(value.periods.map(\.range.start)).count == 2)
    }

    @Test func backfillInitialTarget() throws {
        var value = try state(.daily, created: "2026-11-09T17:00:00Z")
        let id = value.activities[0].id
        value = try PeriodRules.editTarget(
            state: value, edit: TargetEdit(activityID: id, target: 4),
            at: clock("2026-11-10T17:00:00Z")
        )
        value = try PeriodRules.extendTracking(state: value, activityID: id, to: CalendarDay("2026-11-07"))
        #expect(value.periods.map(\.target) == [2, 2, 2, 4])
        #expect(value.periods.allSatisfy { $0.eligibility == .normal })
        #expect(value.activities[0].trackingStartDay.description == "2026-11-07")
    }

    @Test func normalWeekAcrossDSTUsesLocalMidpoint() throws {
        let initial = try state(.weekly, created: "2026-10-26T04:00:00Z")
        let edit = TargetEdit(activityID: initial.activities[0].id, target: 4)
        let exact = try PeriodRules.editTarget(
            state: initial, edit: edit, at: clock("2026-10-29T16:00:00Z")
        )
        #expect(exact.activities[0].effectiveTarget == 4)
        let late = try PeriodRules.editTarget(
            state: initial, edit: edit, at: clock("2026-10-29T16:00:01Z")
        )
        #expect(late.activities[0].pendingTargetStartDay?.description == "2026-11-02")
    }

    @Test func weekdayUsesGregorianDateRatherThanDeviceZone() throws {
        #expect(try CalendarDay("2026-11-09").isoWeekday == 1)
        #expect(try CalendarDay("2026-11-15").isoWeekday == 7)
    }

    @Test func replacingCalendarSettingMovesPendingTarget() throws {
        var value = try state()
        let late = try clock("2026-11-13T17:00:00Z")
        value = try PeriodRules.editTarget(
            state: value, edit: TargetEdit(activityID: value.activities[0].id, target: 4), at: late
        )
        value = try PeriodRules.changeWeekStart(state: value, weekday: 7, at: late)
        value = try PeriodRules.changeWeekStart(state: value, weekday: 2, at: late)
        #expect(value.pendingCalendarSetting?.effectiveDay.description == "2026-11-17")
        #expect(value.activities[0].pendingTargetStartDay?.description == "2026-11-17")
        #expect(value.periods[0].endDayExclusive.description == "2026-11-17")
        let advanced = try PeriodRules.advance(state: value, at: clock("2026-12-01T17:00:00Z"))
        #expect(advanced.calendarRules.count == 1)
        #expect(advanced.weekStartWeekday == 2)
        #expect(advanced.periods.map(\.target) == [2, 4, 4, 4])
    }

    @Test func backfillWithinFirstWeekRemainsPartial() throws {
        let initial = try state(.weekly, created: "2026-11-12T17:00:00Z")
        let value = try PeriodRules.extendTracking(
            state: initial, activityID: initial.activities[0].id, to: CalendarDay("2026-11-10")
        )
        #expect(value.periods[0].eligibility == .initialPartial)
    }
}
