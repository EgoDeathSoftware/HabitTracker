import Foundation

enum CommandRules {
    static func apply(_ command: HabitCommand, to state: inout StoreState,
                      at: ClockReading) throws -> MutationReceipt {
        state.snapshot.timeline = try PeriodRules.advance(state: state.snapshot.timeline, at: at)
        var receipt = MutationReceipt(revision: state.snapshot.revision)
        switch command {
        case let .create(id, draft):
            guard !state.snapshot.timeline.activities.contains(where: { $0.id == id }) else {
                throw HabitError.validation(field: "activity", reason: "This activity already exists.")
            }
            state.snapshot.timeline.activities.append(ActivitySnapshot(id: id, draft: draft, at: at))
            receipt.activityID = id
        case let .rename(id, name, symbol):
            let index = try activityIndex(id, in: state)
            let activity = state.snapshot.timeline.activities[index]
            _ = try HabitDraft(name: name, symbolName: symbol, cadence: activity.cadence,
                              target: activity.effectiveTarget)
            state.snapshot.timeline.activities[index].name = name
            state.snapshot.timeline.activities[index].symbolName = symbol
            receipt.activityID = id
        case let .log(input):
            receipt = try log(input, state: &state, at: at)
        case let .editCompletion(edit):
            try editCompletion(edit, state: &state, at: at)
        case let .deleteCompletion(id):
            guard state.snapshot.completions.contains(where: { $0.id == id }) else {
                throw HabitError.completionUnavailable
            }
            state.snapshot.completions.removeAll { $0.id == id }
        case let .editTarget(edit):
            state.snapshot.timeline = try PeriodRules.editTarget(
                state: state.snapshot.timeline, edit: edit, at: at
            )
            let activity = state.snapshot.timeline.activities[try activityIndex(edit.activityID, in: state)]
            receipt.activityID = edit.activityID
            receipt.effectiveTargetDay = activity.pendingTargetStartDay
                ?? state.snapshot.timeline.periods.first {
                    $0.activityID == edit.activityID && $0.closedAt == nil
                }?.range.start
        case let .changeWeekStart(weekday):
            state.snapshot.timeline = try PeriodRules.changeWeekStart(
                state: state.snapshot.timeline, weekday: weekday, at: at
            )
        case let .deleteActivity(id):
            _ = try activityIndex(id, in: state)
            state.snapshot.timeline.activities.removeAll { $0.id == id }
            state.snapshot.timeline.periods.removeAll { $0.activityID == id }
            state.snapshot.completions.removeAll { $0.activityID == id }
            state.receipts.removeAll { $0.request.activityID == id }
            receipt.activityID = id
        case .refresh: break
        }
        state.snapshot.timeline = try PeriodRules.advance(state: state.snapshot.timeline, at: at)
        return receipt
    }

    private static func log(_ input: LogRequest, state: inout StoreState,
                            at: ClockReading) throws -> MutationReceipt {
        _ = try activityIndex(input.activityID, in: state)
        if let previous = state.receipts.first(where: { $0.request.operationID == input.operationID }) {
            guard previous.request == input else { throw HabitError.operationConflict }
            return MutationReceipt(revision: state.snapshot.revision, activityID: input.activityID,
                                   completionID: previous.completionID, wasReplay: true)
        }
        try validate(day: input.assignedDay, instant: input.occurredAt,
                     zone: input.captureTimeZoneID, at: at)
        state.snapshot.timeline = try PeriodRules.extendTracking(
            state: state.snapshot.timeline, activityID: input.activityID, to: input.assignedDay
        )
        let id = UUID()
        state.snapshot.completions.append(CompletionSnapshot(
            id: id, activityID: input.activityID, assignedDay: input.assignedDay,
            occurredAt: input.occurredAt, captureTimeZoneID: input.captureTimeZoneID,
            createdAt: at.instant, source: input.source, operationID: input.operationID,
            wasTimeOrDateEdited: false
        ))
        state.receipts.append(OperationReceipt(request: input, completionID: id))
        return MutationReceipt(revision: state.snapshot.revision, activityID: input.activityID,
                               completionID: id)
    }

    private static func editCompletion(_ edit: CompletionEdit, state: inout StoreState,
                                       at: ClockReading) throws {
        guard let index = state.snapshot.completions.firstIndex(where: { $0.id == edit.completionID }) else {
            throw HabitError.completionUnavailable
        }
        try validate(day: edit.assignedDay, instant: edit.occurredAt,
                     zone: edit.captureTimeZoneID, at: at)
        let old = state.snapshot.completions[index]
        state.snapshot.timeline = try PeriodRules.extendTracking(
            state: state.snapshot.timeline, activityID: old.activityID, to: edit.assignedDay
        )
        state.snapshot.completions[index] = CompletionSnapshot(
            id: old.id, activityID: old.activityID, assignedDay: edit.assignedDay,
            occurredAt: edit.occurredAt, captureTimeZoneID: edit.captureTimeZoneID,
            createdAt: old.createdAt, source: old.source, operationID: old.operationID,
            wasTimeOrDateEdited: old.wasTimeOrDateEdited || edit.assignedDay != old.assignedDay
                || edit.occurredAt != old.occurredAt || edit.captureTimeZoneID != old.captureTimeZoneID
        )
    }

    private static func activityIndex(_ id: UUID, in state: StoreState) throws -> Int {
        guard let index = state.snapshot.timeline.activities.firstIndex(where: { $0.id == id }) else {
            throw HabitError.activityUnavailable
        }
        return index
    }

    private static func validate(day: CalendarDay, instant: Date?, zone: String,
                                 at: ClockReading) throws {
        guard day <= at.localDay, instant.map({ $0 <= at.instant }) ?? true else {
            throw HabitError.validation(field: "date", reason: "Choose a date and time up to now.")
        }
        guard TimeZone(identifier: zone) != nil else {
            throw HabitError.validation(field: "time zone", reason: "Choose a recognized time zone.")
        }
    }
}
