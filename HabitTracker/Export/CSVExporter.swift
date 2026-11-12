import Foundation

enum CSVExporter {
    static var temporaryDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("HabitTrackerExports", isDirectory: true)
    }

    static func removeInterruptedExports(directory: URL = temporaryDirectory) throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        for url in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            where url.lastPathComponent.hasPrefix("HabitTracker-") && url.pathExtension == "csv" {
            try FileManager.default.removeItem(at: url)
        }
    }

    @concurrent static func export(snapshot: StoreSnapshot, range: DayRange,
                                  at now: ClockReading, directory: URL) async throws -> URL {
        guard range.end <= now.localDay else {
            throw HabitError.validation(field: "export dates", reason: "Choose an end date no later than today.")
        }
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("HabitTracker-\(UUID().uuidString).csv")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
            throw HabitError.saveFailed
        }
        do {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try write("activity_id,activity_name,date,cadence,target,period_start,period_end_exclusive,raw_count,daily_credited_completions,weekly_active_day,period_status", to: handle)
            var rowCount = 0
            for activity in snapshot.timeline.activities.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
                var day = max(range.start, activity.trackingStartDay)
                let periods = snapshot.timeline.periods.filter { $0.activityID == activity.id }
                let counts = snapshot.completions.filter { $0.activityID == activity.id }
                    .reduce(into: [CalendarDay: Int]()) { $0[$1.assignedDay, default: 0] += 1 }
                while day <= range.end {
                    try Task.checkCancellation()
                    if let period = periods.first(where: { $0.range.contains(day) }) {
                        let raw = counts[day, default: 0]
                        let daily = activity.cadence == .daily ? String(min(raw, period.target)) : ""
                        let weekly = activity.cadence == .weekly ? String(raw > 0 ? 1 : 0) : ""
                        let row = [activity.id.uuidString, cell(activity.name), day.description,
                            activity.cadence.rawValue, String(period.target), period.range.start.description,
                            period.endDayExclusive.description, String(raw), daily, weekly, status(period)]
                        try write(row.joined(separator: ","), to: handle)
                        rowCount += 1
                    }
                    if day == range.end { break }
                    day = try day.adding(days: 1)
                }
            }
            guard rowCount > 0 else {
                throw HabitError.validation(field: "export dates", reason: "No tracked activity dates fall within this range.")
            }
            try Task.checkCancellation()
            try handle.close()
            return url
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    private static func status(_ period: GoalPeriodSnapshot) -> String {
        switch period.eligibility {
        case .initialPartial: "initial_partial"
        case .transitional: "transitional"
        case .normal: period.closedAt == nil ? "in_progress" : "complete"
        }
    }

    private static func cell(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines.union(.controlCharacters))
        let value = trimmed.first.map { "=+-@".contains($0) } == true ? "'" + text : text
        guard value.rangeOfCharacter(from: CharacterSet(charactersIn: ",\"\r\n")) != nil else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func write(_ row: String, to handle: FileHandle) throws {
        try handle.write(contentsOf: Data((row + "\r\n").utf8))
    }
}
