import SwiftUI

struct ReportsView: View {
    @Environment(AppEnvironment.self) private var environment
    let activity: ActivitySnapshot
    @State private var span = ReportSpan.week
    @State private var selectedDate = Date()
    @State private var report: HabitReport?
    @State private var error: String?

    var body: some View {
        let request = try? ReportRequest(activityID: activity.id, span: span,
            anchor: ClockReading(instant: selectedDate, timeZone: .current).localDay)
        List {
            Picker("Report period", selection: $span) {
                ForEach(ReportSpan.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            DatePicker("Date in period", selection: $selectedDate, in: ...Date(),
                       displayedComponents: .date)
            if let report { reportSections(report) }
            else if let error { Text(error) }
            else { ProgressView("Calculating report") }
        }
        .navigationTitle("Progress")
        .task(id: Calculation(request: request, revision: environment.snapshot.revision)) {
            report = nil
            error = nil
            guard let request else { return }
            do {
                let now = try ClockReading(instant: Date(), timeZone: .current)
                let result = try await ReportCalculator.calculate(
                    snapshot: environment.snapshot, request: request, at: now
                )
                if !Task.isCancelled { report = result }
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription }
            }
        }
    }

    private struct Calculation: Hashable {
        let request: ReportRequest?
        let revision: Int64
    }

    @ViewBuilder private func reportSections(_ report: HabitReport) -> some View {
        Section("Completed goals") {
            Text(label(report.range)).font(.subheadline)
            Text(summary(report.total))
            if let trend = report.trend {
                Text("\(label(trend.previous)) → \(label(trend.latest))")
                Text("\(trend.percentagePoints.formatted(.number.precision(.fractionLength(0...1)))) percentage points")
            } else { Text("Trend unavailable").foregroundStyle(.secondary) }
        }
        let separate = report.goals.filter { !$0.eligible || $0.period.cadence == .weekly }
        if !separate.isEmpty {
            Section(activity.cadence == .weekly ? "Weekly goals" : "Open and partial goals") {
                ForEach(separate, id: \.period.range.start) { goal in
                    LabeledContent(label(goal.period.range)) {
                        Text(status(goal))
                    }
                }
            }
        }
        if !report.breakdown.isEmpty {
            Section(span == .year ? "By month" : "By week") {
                ForEach(report.breakdown, id: \.range.start) { group in
                    LabeledContent(label(group.range), value: summary(group.total))
                }
            }
        }
        Section("Calendar") {
            ForEach(report.days) { day in
                LabeledContent(day.date.description) {
                    VStack(alignment: .trailing) {
                        Text("\(day.count) recorded")
                        if let goal = day.dailyGoal { Text(status(goal)).font(.caption) }
                    }
                }
            }
        }
    }

    private func label(_ range: DayRange) -> String {
        range.start == range.end ? range.start.description : "\(range.start) – \(range.end)"
    }

    private func summary(_ total: ReportTotal) -> String {
        guard let percent = total.percent else { return "Not enough history" }
        return "\(percent)% adherence · \(total.met) of \(total.periods) goals met"
    }

    private func status(_ goal: HabitReport.Goal) -> String {
        let progress = goal.progress
        let count = "\(progress.creditedUnits) of \(progress.target)"
        if goal.period.eligibility != .normal { return "\(count) · Partial period" }
        if goal.period.closedAt == nil {
            return "\(count) · \(progress.target - progress.creditedUnits) remaining"
        }
        return "\(count) · \(progress.isMet ? "Goal met" : "Goal missed")"
    }
}
