import Foundation
import Testing
@testable import HabitTracker

struct CSVExportTests {
    @Test func weeklyObservationsAndStatusPrecedence() async throws {
        let now = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-11T12:00:00Z")!, timeZone: .gmt)
        let id = UUID()
        let first = try CalendarDay("2026-11-09")
        let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Walk", symbolName: "figure.walk", cadence: .weekly, target: 1), createdAt: first.midnight(in: .gmt), createdDay: first)
        var period = try GoalPeriodSnapshot(activityID: id, cadence: .weekly,
            range: DayRange(start: first, end: CalendarDay("2026-11-15")), target: 1)
        let logs = try FixtureFactory.logs(["2026-11-09", "2026-11-09", "2026-11-10"], activityID: id)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        for (eligibility, expected) in [(PeriodEligibility.normal, "in_progress"), (.initialPartial, "initial_partial"), (.transitional, "transitional")] {
            period.eligibility = eligibility
            let snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity], periods: [period]), completions: logs)
            let url = try await CSVExporter.export(snapshot: snapshot,
                range: DayRange(start: first, end: now.localDay), at: now, directory: directory)
            let rows = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\r\n").filter { !$0.isEmpty }.dropFirst()
            let cells = rows.map { $0.components(separatedBy: ",") }
            #expect(cells.map { $0[7] } == ["2", "1", "0"])
            #expect(cells.map { $0[9] } == ["1", "1", "0"])
            #expect(cells.allSatisfy { $0[8].isEmpty && $0[10] == expected })
        }
    }

    @Test func tenYearsOfTwentyFiveHabits() async throws {
        let now = try ClockReading(instant: Date(), timeZone: .gmt)
        let first = try now.localDay.adding(days: -3652)
        let created = try ClockReading(instant: first.midnight(in: .gmt), timeZone: .gmt)
        var timeline = TimelineState()
        for _ in 0..<25 {
            let id = UUID()
            timeline.activities.append(ActivitySnapshot(id: id, draft: try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 1), at: created))
            for offset in 0...3652 {
                let day = try first.adding(days: offset)
                timeline.periods.append(try GoalPeriodSnapshot(activityID: id, cadence: .daily,
                    range: DayRange(start: day, end: day), target: 1))
            }
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let started = ContinuousClock.now
        let url = try await CSVExporter.export(snapshot: StoreSnapshot(timeline: timeline),
            range: DayRange(start: first, end: now.localDay), at: now, directory: directory)
        print("Ten-year, 25-habit export duration \(started.duration(to: .now))")
        let rows = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(rows.count == 1 + 25 * 3653)
    }

    @Test func cancellationDuringLargeExport() async throws {
        let now = try ClockReading(instant: Date(), timeZone: .gmt)
        let first = try now.localDay.adding(days: -10000)
        let created = try ClockReading(instant: first.midnight(in: .gmt), timeZone: .gmt)
        let id = UUID()
        let activity = ActivitySnapshot(id: id, draft: try HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 1), at: created)
        var periods: [GoalPeriodSnapshot] = []
        for offset in 0...10000 {
            let day = try first.adding(days: offset)
            periods.append(try GoalPeriodSnapshot(activityID: id, cadence: .daily,
                range: DayRange(start: day, end: day), target: 1))
        }
        let snapshot = StoreSnapshot(timeline: TimelineState(activities: [activity], periods: periods))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let range = try DayRange(start: first, end: now.localDay)
        let writing = Task { try await CSVExporter.export(snapshot: snapshot, range: range, at: now, directory: directory) }
        var observedFile = false
        for _ in 0..<1000 {
            if try !FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty {
                observedFile = true
                break
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        writing.cancel()
        #expect(observedFile)
        await #expect(throws: CancellationError.self) { try await writing.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test func assignedDatesAndHistoricalTargets() async throws {
        let start = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-09T00:00:00Z")!, timeZone: .gmt)
        let next = try ClockReading(instant: start.instant.addingTimeInterval(86400), timeZone: .gmt)
        let id = UUID()
        var state = StoreState()
        _ = try CommandRules.apply(.create(id, HabitDraft(name: "Read", symbolName: "book", cadence: .daily, target: 1)), to: &state, at: start)
        _ = try CommandRules.apply(.refresh, to: &state, at: next)
        _ = try CommandRules.apply(.editTarget(TargetEdit(activityID: id, target: 3)), to: &state, at: next)
        state.snapshot.completions = try FixtureFactory.logs(["2026-11-09"], activityID: id)
        let travel = try ClockReading(instant: next.instant, timeZone: TimeZone(identifier: "Asia/Tokyo")!)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try await CSVExporter.export(snapshot: state.snapshot,
            range: DayRange(start: start.localDay.adding(days: -5), end: next.localDay), at: travel, directory: directory)
        let rows = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\r\n").filter { !$0.isEmpty }.dropFirst()
        let cells = rows.map { $0.components(separatedBy: ",") }
        #expect(cells.map { $0[2] } == ["2026-11-09", "2026-11-10"])
        #expect(cells.map { $0[4] } == ["1", "3"])
        #expect(cells.map { $0[7] } == ["1", "0"])
        #expect(cells.map { $0[10] } == ["complete", "in_progress"])
        #expect(state.snapshot.completions.first?.occurredAt == nil)
    }

    @Test func validationCancellationAndCleanup() async throws {
        let now = try ClockReading(instant: Date(), timeZone: .gmt)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let today = try DayRange(start: now.localDay, end: now.localDay)
        await #expect(throws: HabitError.self) {
            try await CSVExporter.export(snapshot: StoreSnapshot(), range: today, at: now, directory: directory)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
        let future = try DayRange(start: now.localDay, end: now.localDay.adding(days: 1))
        await #expect(throws: HabitError.self) {
            try await CSVExporter.export(snapshot: StoreSnapshot(), range: future, at: now, directory: directory)
        }
        #expect(throws: HabitError.self) { try DayRange(start: now.localDay.adding(days: 1), end: now.localDay) }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await CSVExporter.export(snapshot: StoreSnapshot(), range: today, at: now, directory: directory)
        }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        let stale = directory.appendingPathComponent("HabitTracker-interrupted.csv")
        let unrelated = directory.appendingPathComponent("keep.txt")
        try Data("partial".utf8).write(to: stale)
        try Data("keep".utf8).write(to: unrelated)
        try CSVExporter.removeInterruptedExports(directory: directory)
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(FileManager.default.fileExists(atPath: unrelated.path))
    }

    @Test(arguments: [
        (" \t=SUM(1,2)", "\"' \t=SUM(1,2)\""),
        ("\t+1", "'\t+1"),
        ("\r\n-2", "\"'\r\n-2\""),
        ("\u{0001}@command", "'\u{0001}@command"),
        ("Café, \"日\"\r\nwalk", "\"Café, \"\"日\"\"\r\nwalk\"")
    ])
    func escapedNames(_ example: (String, String)) async throws {
        let (name, expectedCell) = example
        let now = try ClockReading(instant: Date(), timeZone: .gmt)
        var state = StoreState()
        _ = try CommandRules.apply(.create(UUID(), HabitDraft(name: name, symbolName: "book", cadence: .weekly, target: 1)), to: &state, at: now)
        _ = try CommandRules.apply(.refresh, to: &state, at: now)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try await CSVExporter.export(snapshot: state.snapshot,
            range: DayRange(start: now.localDay, end: now.localDay), at: now, directory: directory)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("," + expectedCell + ","))
        #expect(state.snapshot.timeline.activities.first?.name == name)
        #expect(text.contains(",0,,0,"))
    }

    @Test func rangeAndEscaping() async throws {
        let zone = TimeZone.gmt
        let start = try ClockReading(instant: ISO8601DateFormatter().date(from: "2026-11-09T00:00:00Z")!, timeZone: zone)
        let now = try ClockReading(instant: start.instant.addingTimeInterval(2 * 86400), timeZone: zone)
        let id = UUID()
        var state = StoreState()
        _ = try CommandRules.apply(.create(id, HabitDraft(name: "=1+1", symbolName: "book", cadence: .daily, target: 1)), to: &state, at: start)
        _ = try CommandRules.apply(.refresh, to: &state, at: now)
        state.snapshot.completions = try FixtureFactory.logs(["2026-11-09", "2026-11-11", "2026-11-11"], activityID: id)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = try await CSVExporter.export(snapshot: state.snapshot,
            range: DayRange(start: start.localDay, end: now.localDay), at: now, directory: directory)
        let contents = try String(contentsOf: url, encoding: .utf8)
        let rows = contents.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(rows.count == 4)
        #expect(rows[0] == "activity_id,activity_name,date,cadence,target,period_start,period_end_exclusive,raw_count,daily_credited_completions,weekly_active_day,period_status")
        let cells = rows.dropFirst().map { $0.components(separatedBy: ",") }
        #expect(cells.map { $0[7] } == ["1", "0", "2"])
        #expect(cells.map { $0[8] } == ["1", "0", "1"])
        #expect(cells.allSatisfy { $0[1] == "'=1+1" && $0[9].isEmpty })
        #expect(state.snapshot.timeline.activities.first?.name == "=1+1")
        try FileManager.default.removeItem(at: directory)
    }
}
