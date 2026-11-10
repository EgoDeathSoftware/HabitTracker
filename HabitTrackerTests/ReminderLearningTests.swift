import Foundation
import Testing
@testable import HabitTracker

struct ReminderLearningTests {
    @Test func slotsThresholdsAndNotices() throws {
        let now = try clock("2026-11-10")
        let start = try clock("2026-10-01")
        let id = UUID()
        let draft = try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 2)
        let activity = ActivitySnapshot(id: id, draft: draft, at: start)
        let config = ReminderConfiguration(activityID: id, isEnabled: true, target: 2,
            learningStartedAt: start.instant, learningStartDay: start.localDay,
            slots: [540, 1080].map(ReminderSlot.init))
        var snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity]),
                                     reminders: [id: config])
        for offset in 1...4 {
            let day = try now.localDay.adding(days: -offset)
            snapshot.completions += [log(id, day, 600), log(id, day, 1140), log(id, day, 1200)]
        }
        let fifth = try now.localDay.adding(days: -5)
        snapshot.completions += [log(id, fifth, 600), log(id, fifth, 1000, source: .manual),
                                 log(id, fifth, 1050, edited: true), log(id, now.localDay, 600)]
        #expect(ReminderLearning.evaluate(snapshot: snapshot, at: now).first?.changes.isEmpty == true)
        snapshot.completions.append(log(id, fifth, 1140))
        var newlyEnabled = snapshot
        newlyEnabled.reminders.removeAll()
        try ReminderRules.edit(.init(activityID: id, isEnabled: true, minutes: [540, 1080]),
                               in: &newlyEnabled, at: now)
        #expect(ReminderLearning.evaluate(snapshot: newlyEnabled, at: now).first?.qualifyingDateCount == 5)
        ReminderLearning.apply(to: &snapshot, at: now)
        #expect(snapshot.reminders[id]?.slots.map(\.effectiveMinute) == [570, 1110])
        #expect(snapshot.notices.count == 1)
        #expect(snapshot.notices.first?.changes.count == 2)
        ReminderLearning.apply(to: &snapshot, at: now)
        ReminderLearning.apply(to: &snapshot, at: try clock("2026-11-09"))
        #expect(snapshot.notices.count == 1)
    }

    @Test func midnightCircularMedianAndSpacing() {
        #expect(ReminderLearning.circularMedian([1430, 1435, 0, 5, 10], near: 1410) == 0)
        #expect(ReminderLearning.circularMedian([60, 90], near: 80) == 80)
        #expect(ReminderLearning.validMinutes([0, 1410]))
        #expect(!ReminderLearning.validMinutes([0, 1420]))
        #expect(!ReminderLearning.validMinutes([540, 500]))
    }

    @Test func targetChangeResetsSamples() throws {
        let now = try clock("2026-11-10")
        let start = try clock("2026-10-01")
        let id = UUID()
        let draft = try HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .weekly, target: 2)
        let activity = ActivitySnapshot(id: id, draft: draft, at: start)
        var configuration = ReminderConfiguration(activityID: id, isEnabled: true, target: 2,
            learningStartedAt: start.instant, learningStartDay: start.localDay,
            slots: [ReminderSlot(minute: 540)])
        let logs = try (1...5).flatMap { offset in
            let day = try now.localDay.adding(days: -offset * 7)
            return [log(id, day, 600), log(id, day, 1200)]
        }
        var snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity]),
                                     completions: logs, reminders: [id: configuration])
        #expect(ReminderLearning.evaluate(snapshot: snapshot, at: now).first?.changes.first?.newMinute == 570)
        configuration.learningStartedAt = now.instant
        configuration.learningStartDay = now.localDay
        snapshot.reminders[id] = configuration
        #expect(ReminderLearning.evaluate(snapshot: snapshot, at: now).first?.qualifyingDateCount == 0)
    }

    @Test func targetIncreaseRequiresSeedsAndDecreaseKeepsFirstSlot() throws {
        let now = try clock("2026-11-10")
        let id = UUID()
        let draft = try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 2)
        var state = StoreState()
        _ = try CommandRules.apply(.create(id, draft), to: &state, at: now)
        #expect(state.snapshot.reminders.isEmpty)
        _ = try CommandRules.apply(.editReminders(.init(activityID: id, isEnabled: true,
            minutes: [540, 1080])), to: &state, at: now)
        var invalid = state
        #expect(throws: HabitError.self) {
            try CommandRules.apply(.editTarget(.init(activityID: id, target: 3)),
                                   to: &invalid, at: now)
        }
        let later = try clock("2026-11-11")
        _ = try CommandRules.apply(.editTarget(.init(activityID: id, target: 3,
            addedSlotSeedMinutes: [1200])), to: &state, at: later)
        #expect(state.snapshot.reminders[id]?.slots.map(\.seedMinute) == [540, 1080, 1200])
        #expect(state.snapshot.reminders[id]?.learningStartedAt == later.instant)
        _ = try CommandRules.apply(.editTarget(.init(activityID: id, target: 1)), to: &state, at: later)
        #expect(state.snapshot.reminders[id]?.slots.map(\.effectiveMinute) == [540])
    }

    private let zone = TimeZone(secondsFromGMT: 0)!

    private func clock(_ day: String) throws -> ClockReading {
        try ClockReading(instant: CalendarDay(day).midnight(in: zone), timeZone: zone)
    }

    private func log(_ id: UUID, _ day: CalendarDay, _ minute: Int,
                     source: CompletionSource = .app, edited: Bool = false) -> CompletionSnapshot {
        let instant = day.midnight(in: zone).addingTimeInterval(Double(minute * 60))
        return CompletionSnapshot(id: UUID(), activityID: id, assignedDay: day, occurredAt: instant,
            captureTimeZoneID: zone.identifier, createdAt: instant, source: source,
            operationID: UUID(), wasTimeOrDateEdited: edited)
    }
}
