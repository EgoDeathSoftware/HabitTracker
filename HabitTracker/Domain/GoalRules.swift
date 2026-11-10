enum GoalRules {
    static func progress(
        period: GoalPeriodSnapshot, completions: [CompletionSnapshot]
    ) -> GoalProgress {
        let matching = completions.filter {
            $0.activityID == period.activityID && period.range.contains($0.assignedDay)
        }
        let units = period.cadence == .daily
            ? matching.count : Set(matching.map(\.assignedDay)).count
        return GoalProgress(
            rawCount: matching.count, creditedUnits: min(units, period.target), target: period.target
        )
    }
}
