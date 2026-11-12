import Foundation
import Testing
@testable import HabitTracker

struct NotificationPlannerTests {
    @Test func stableOrderingAndWeekTransition() throws {
        let now = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z")!, timeZone: .gmt)
        var state = StoreState()
        let ids = (1...3).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", $0))! }
        for id in ids.reversed() {
            _ = try CommandRules.apply(.create(id, HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .weekly, target: 1)), to: &state, at: now)
            _ = try CommandRules.apply(.editReminders(ReminderEdit(activityID: id, isEnabled: true, minutes: [540])), to: &state, at: now)
        }
        _ = try CommandRules.apply(.changeWeekStart(3), to: &state, at: now)
        for id in ids {
            state.snapshot.completions += try FixtureFactory.logs(["2026-11-10"], activityID: id)
        }
        let plan = NotificationPlanner.plan(snapshot: state.snapshot, at: now)
        #expect(plan.count == 60)
        #expect(Array(plan.prefix(3)).map(\.activityID) == ids)
        #expect(plan.first?.day == (try CalendarDay("2026-11-11")))
        #expect(plan.allSatisfy { $0.day < (try! now.localDay.adding(days: 28)) })
    }

    @Test func pendingTargetProjection() throws {
        let now = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-13T12:00:00Z")!, timeZone: .gmt)
        let id = UUID()
        var state = StoreState()
        _ = try CommandRules.apply(.create(id, HabitDraft(name: "Read", symbolName: "book", cadence: .weekly, target: 1)), to: &state, at: now)
        _ = try CommandRules.apply(.editReminders(ReminderEdit(activityID: id, isEnabled: true, minutes: [540])), to: &state, at: now)
        let request = LogRequest(activityID: id, operationID: UUID(), assignedDay: now.localDay,
            occurredAt: now.instant, captureTimeZoneID: now.timeZoneID, source: .app)
        _ = try CommandRules.apply(.log(request), to: &state, at: now)
        _ = try CommandRules.apply(.editTarget(TargetEdit(activityID: id, target: 2)), to: &state, at: now)
        #expect(state.snapshot.timeline.activities.first?.pendingTarget == 2)
        let planned = NotificationPlanner.plan(snapshot: state.snapshot, at: now)
        let tomorrow = try CalendarDay("2026-11-16")
        #expect(planned.allSatisfy { $0.day != now.localDay })
        #expect(planned.first?.day == tomorrow)
        #expect(planned.filter { $0.day == tomorrow }.map(\.slot) == [0])
        #expect(state.snapshot.reminders[id]?.slots.count == 1)
    }

    @Test func weeklySuppressionAndFutureOnly() throws {
        let now = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-10T12:00:00Z")!, timeZone: .gmt)
        let id = UUID()
        let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .weekly, target: 2), at: now)
        let config = ReminderConfiguration(activityID: id, isEnabled: true, target: 2,
            learningStartedAt: now.instant, learningStartDay: now.localDay, slots: [ReminderSlot(minute: 1080)])
        var snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity]), reminders: [id: config])
        snapshot.completions = try FixtureFactory.logs(["2026-11-10"], activityID: id)
        let todayLogged = NotificationPlanner.plan(snapshot: snapshot, at: now)
        #expect(todayLogged.allSatisfy { $0.day != now.localDay })
        #expect(todayLogged.first?.day == (try now.localDay.adding(days: 1)))
        snapshot.completions += try FixtureFactory.logs(["2026-11-11"], activityID: id)
        let weekMet = NotificationPlanner.plan(snapshot: snapshot, at: now)
        #expect(weekMet.first?.day == (try CalendarDay("2026-11-16")))
        snapshot.completions.removeAll()
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: now).first?.day == now.localDay)
        let later = try ClockReading(instant: now.instant.addingTimeInterval(7 * 3600), timeZone: .gmt)
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: later).allSatisfy { $0.fireDate > later.instant && $0.day != later.localDay })
        let travel = try ClockReading(instant: now.instant, timeZone: TimeZone(identifier: "America/New_York")!)
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: travel).first?.id != NotificationPlanner.plan(snapshot: snapshot, at: now).first?.id)
        let expired = try ClockReading(instant: now.instant.addingTimeInterval(40 * 86400), timeZone: .gmt)
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: expired).allSatisfy { $0.fireDate > expired.instant })
    }

    @Test func dstOnce() throws {
        let zone = TimeZone(identifier: "America/New_York")!
        for (start, minute, expected) in [
            ("2026-03-08T05:00:00Z", 150, "2026-03-08T07:00:00Z"),
            ("2026-11-01T04:00:00Z", 90, "2026-11-01T05:30:00Z")
        ] {
            let formatter = ISO8601DateFormatter()
            let now = try ClockReading(instant: formatter.date(from: start)!, timeZone: zone)
            let id = UUID()
            let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .daily, target: 1), at: now)
            let config = ReminderConfiguration(activityID: id, isEnabled: true, target: 1,
                learningStartedAt: now.instant, learningStartDay: now.localDay,
                slots: [ReminderSlot(minute: minute)])
            let snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity]), reminders: [id: config])
            let today = NotificationPlanner.plan(snapshot: snapshot, at: now).filter { $0.day == now.localDay }
            #expect(today.count == 1)
            #expect(today.first?.fireDate == formatter.date(from: expected))
        }
    }

    @Test func capacitySuppressionAndCorrection() throws {
        let now = try ClockReading(instant: Date(timeIntervalSince1970: 1794268800), timeZone: .gmt)
        let id = UUID()
        let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 3), at: now)
        let config = ReminderConfiguration(activityID: id, isEnabled: true, target: 3,
            learningStartedAt: now.instant, learningStartDay: now.localDay,
            slots: [540, 720, 1080].map(ReminderSlot.init))
        var snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity]), reminders: [id: config])
        let requests = NotificationPlanner.plan(snapshot: snapshot, at: now)
        #expect(requests.count == 60)
        #expect(Set(requests.map(\.id)).count == 60)
        #expect(requests == NotificationPlanner.plan(snapshot: snapshot, at: now))
        snapshot.completions = (0..<3).map { _ in
            CompletionSnapshot(id: UUID(), activityID: id, assignedDay: now.localDay,
                occurredAt: now.instant, captureTimeZoneID: now.timeZoneID,
                createdAt: now.instant, source: .app, operationID: UUID(), wasTimeOrDateEdited: false)
        }
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: now).allSatisfy { $0.day != now.localDay })
        snapshot.completions.removeAll()
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: now).first?.day == now.localDay)
        snapshot.reminders[id]?.isEnabled = false
        #expect(NotificationPlanner.plan(snapshot: snapshot, at: now).isEmpty)
    }
}
