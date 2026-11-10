import Foundation

struct LogRequest: Equatable, Sendable {
    let activityID: UUID
    let operationID: UUID
    let assignedDay: CalendarDay
    let occurredAt: Date?
    let captureTimeZoneID: String
    let source: CompletionSource
}

struct CompletionEdit: Sendable {
    let completionID: UUID
    let assignedDay: CalendarDay
    let occurredAt: Date?
    let captureTimeZoneID: String
}

enum HabitCommand: Sendable {
    case create(UUID, HabitDraft)
    case rename(UUID, name: String, symbolName: String)
    case log(LogRequest)
    case editCompletion(CompletionEdit)
    case deleteCompletion(UUID)
    case editTarget(TargetEdit)
    case changeWeekStart(Int)
    case deleteActivity(UUID)
    case editReminders(ReminderEdit)
    case acknowledgeNotice(UUID)
    case refresh
}

struct MutationReceipt: Equatable, Sendable {
    let revision: Int64
    var activityID: UUID?
    var completionID: UUID?
    var wasReplay = false
    var effectiveTargetDay: CalendarDay?
}

struct SnapshotQuery: Sendable {
    var activityID: UUID?
    var range: DayRange?
}

struct StoreSnapshot: Equatable, Sendable {
    var timeline = TimelineState()
    var completions: [CompletionSnapshot] = []
    var revision: Int64 = 0
    var reminders: [UUID: ReminderConfiguration] = [:]
    var notices: [AdjustmentNotice] = []
}

struct OperationReceipt: Equatable, Sendable {
    let request: LogRequest
    let completionID: UUID
}

struct StoreState: Equatable, Sendable {
    var snapshot = StoreSnapshot()
    var receipts: [OperationReceipt] = []
}
