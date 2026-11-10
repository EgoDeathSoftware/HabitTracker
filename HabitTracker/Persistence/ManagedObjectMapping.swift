import CoreData
import Foundation

extension ManagedObjectMapping {
    private static func loadReminders(into snapshot: inout StoreSnapshot,
                                      context: NSManagedObjectContext) throws {
        for row in try rows("ReminderConfiguration", context) {
            let id: UUID = try required(row, "activityID")
            let slots = try orderedChildren(row, "slots").map { child in
                var slot = try ReminderSlot(minute: integer(child, "seedMinute"))
                slot.effectiveMinute = try integer(child, "effectiveMinute")
                if let day = child.value(forKey: "lastAdjustedDay") as? String {
                    slot.lastAdjustedDay = try CalendarDay(day)
                }
                return slot
            }
            snapshot.reminders[id] = try ReminderConfiguration(
                activityID: id, isEnabled: required(row, "enabled"),
                target: integer(row, "target"), learningStartedAt: required(row, "learningStartedAt"),
                learningStartDay: CalendarDay(required(row, "learningStartDay")), slots: slots,
                pendingSeeds: orderedChildren(row, "pendingSeeds").map { try integer($0, "minute") }
            )
        }
        snapshot.notices = try rows("AdjustmentNotice", context).map { row in
            try AdjustmentNotice(id: required(row, "id"), activityID: required(row, "activityID"),
                createdAt: required(row, "createdAt"), reason: required(row, "reason"),
                changes: orderedChildren(row, "changes").map {
                    try ReminderChange(slotIndex: integer($0, "slotIndex"),
                                       oldMinute: integer($0, "oldMinute"), newMinute: integer($0, "newMinute"))
                }, acknowledgedAt: row.value(forKey: "acknowledgedAt") as? Date)
        }.sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
    }

    private static func orderedChildren(_ row: NSManagedObject, _ key: String) throws
        -> [NSManagedObject] {
        let children = row.value(forKey: key) as? Set<NSManagedObject> ?? []
        return try children.map { (try integer($0, "slotIndex"), $0) }
            .sorted { $0.0 < $1.0 }.map(\.1)
    }

    private static func saveReminders(_ snapshot: StoreSnapshot, activities: [String: NSManagedObject],
                                      context: NSManagedObjectContext) throws {
        let configs = try sync("ReminderConfiguration", records: snapshot.reminders.values.map { config in
            let id = config.activityID.uuidString
            return (id, ["activityID": config.activityID, "activity": activities[id] as Any?,
                         "enabled": config.isEnabled, "target": config.target,
                         "learningStartedAt": config.learningStartedAt,
                         "learningStartDay": config.learningStartDay.description])
        }, key: { try required($0, "activityID") as UUID }, context: context)
        _ = try sync("ReminderSlot", records: snapshot.reminders.values.flatMap { config in
            config.slots.enumerated().map { index, slot in
                let id = config.activityID.uuidString
                return ("\(id):\(index)", ["activityID": config.activityID, "slotIndex": index,
                    "configuration": configs[id] as Any?, "seedMinute": slot.seedMinute,
                    "effectiveMinute": slot.effectiveMinute,
                    "lastAdjustedDay": slot.lastAdjustedDay?.description as Any?])
            }
        }, stringKey: { try childKey($0, owner: "activityID") }, context: context)
        _ = try sync("PendingReminderSeed", records: snapshot.reminders.values.flatMap { config in
            config.pendingSeeds.enumerated().map { index, minute in
                let id = config.activityID.uuidString
                return ("\(id):\(index)", ["activityID": config.activityID, "slotIndex": index,
                                          "configuration": configs[id] as Any?, "minute": minute])
            }
        }, stringKey: { try childKey($0, owner: "activityID") }, context: context)
        try saveNotices(snapshot.notices, activities: activities, context: context)
    }

    private static func saveNotices(_ notices: [AdjustmentNotice], activities: [String: NSManagedObject],
                                    context: NSManagedObjectContext) throws {
        let parents = try sync("AdjustmentNotice", records: notices.map { notice in
            (notice.id.uuidString, ["id": notice.id, "activityID": notice.activityID,
                "activity": activities[notice.activityID.uuidString] as Any?,
                "createdAt": notice.createdAt, "reason": notice.reason,
                "acknowledgedAt": notice.acknowledgedAt as Any?])
        }, key: { try required($0, "id") as UUID }, context: context)
        _ = try sync("AdjustmentChange", records: notices.flatMap { notice in
            notice.changes.map { change in
                let id = notice.id.uuidString
                return ("\(id):\(change.slotIndex)", ["noticeID": notice.id,
                    "notice": parents[id] as Any?, "slotIndex": change.slotIndex,
                    "oldMinute": change.oldMinute, "newMinute": change.newMinute])
            }
        }, stringKey: { try childKey($0, owner: "noticeID") }, context: context)
    }

    private static func childKey(_ row: NSManagedObject, owner: String) throws -> String {
        let id: UUID = try required(row, owner)
        return "\(id.uuidString):\(try integer(row, "slotIndex"))"
    }
}

enum ManagedObjectMapping {
    static func load(_ context: NSManagedObjectContext) throws -> StoreState {
        var state = StoreState()
        state.snapshot.timeline.activities = try rows("Activity", context).map(activity)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        state.snapshot.timeline.periods = try rows("GoalPeriod", context).map(period)
            .sorted {
                if $0.activityID == $1.activityID { return $0.range.start < $1.range.start }
                return $0.activityID.uuidString < $1.activityID.uuidString
            }
        state.snapshot.completions = try rows("Completion", context).map(completion)
            .sorted { $0.id.uuidString < $1.id.uuidString }
        state.receipts = try rows("OperationReceipt", context).map { row in
            try OperationReceipt(request: LogRequest(
                activityID: required(row, "activityID"), operationID: required(row, "operationID"),
                assignedDay: CalendarDay(required(row, "assignedDay")),
                occurredAt: row.value(forKey: "occurredAt") as? Date,
                captureTimeZoneID: required(row, "captureTimeZoneID"),
                source: source(row)
            ), completionID: required(row, "completionID"))
        }.sorted { $0.request.operationID.uuidString < $1.request.operationID.uuidString }
        state.snapshot.timeline.calendarRules = try rows("CalendarRule", context).map { row in
            try CalendarRule(
                id: required(row, "id"), effectiveStartDay: CalendarDay(required(row, "effectiveStartDay")),
                weekStartWeekday: integer(row, "weekStartWeekday"), createdAt: required(row, "createdAt")
            )
        }.sorted { $0.effectiveStartDay < $1.effectiveStartDay }
        if let settings = try rows("AppSettings", context).first {
            state.snapshot.revision = try required(settings, "revision")
            state.snapshot.timeline.weekStartWeekday = try integer(settings, "weekStartWeekday")
            if let weekday = settings.value(forKey: "pendingWeekday") as? NSNumber,
               let day = settings.value(forKey: "pendingEffectiveDay") as? String {
                state.snapshot.timeline.pendingCalendarSetting = try PendingCalendarSetting(
                    weekday: weekday.intValue, effectiveDay: CalendarDay(day)
                )
            }
        }
        if NSEntityDescription.entity(forEntityName: "ReminderConfiguration", in: context) != nil {
            try loadReminders(into: &state.snapshot, context: context)
        }
        return state
    }

    static func save(_ state: StoreState, in context: NSManagedObjectContext) throws {
        let activities = try sync(
            "Activity", records: state.snapshot.timeline.activities.map { ($0.id.uuidString, activityFields($0)) },
            key: { try required($0, "id") as UUID }, context: context
        )
        let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.key, $0.value) })
        try saveChildren(state, activities: activityMap, context: context)
        if NSEntityDescription.entity(forEntityName: "ReminderConfiguration", in: context) != nil {
            try saveReminders(state.snapshot, activities: activityMap, context: context)
        }
        _ = try sync("CalendarRule", records: state.snapshot.timeline.calendarRules.map {
            ($0.id.uuidString, ["id": $0.id, "effectiveStartDay": $0.effectiveStartDay.description,
                               "weekStartWeekday": $0.weekStartWeekday, "createdAt": $0.createdAt])
        }, key: { try required($0, "id") as UUID }, context: context)
        let settings = try rows("AppSettings", context).first
            ?? NSEntityDescription.insertNewObject(forEntityName: "AppSettings", into: context)
        set(["key": "settings", "revision": state.snapshot.revision,
             "weekStartWeekday": state.snapshot.timeline.weekStartWeekday,
             "pendingWeekday": state.snapshot.timeline.pendingCalendarSetting?.weekday as Any?,
             "pendingEffectiveDay": state.snapshot.timeline.pendingCalendarSetting?.effectiveDay.description
                as Any?], on: settings)
    }

    private static func saveChildren(_ state: StoreState, activities: [String: NSManagedObject],
                                      context: NSManagedObjectContext) throws {
        _ = try sync("Completion", records: state.snapshot.completions.map {
            ($0.id.uuidString, ["id": $0.id, "activityID": $0.activityID,
                               "activity": activities[$0.activityID.uuidString] as Any?,
                               "assignedDay": $0.assignedDay.description, "occurredAt": $0.occurredAt as Any?,
                               "captureTimeZoneID": $0.captureTimeZoneID, "createdAt": $0.createdAt,
                               "source": $0.source.rawValue, "operationID": $0.operationID,
                               "wasTimeOrDateEdited": $0.wasTimeOrDateEdited])
        }, key: { try required($0, "id") as UUID }, context: context)
        _ = try sync("OperationReceipt", records: state.receipts.map {
            let input = $0.request
            return (input.operationID.uuidString, ["operationID": input.operationID,
                "activityID": input.activityID, "activity": activities[input.activityID.uuidString] as Any?,
                "completionID": $0.completionID, "assignedDay": input.assignedDay.description,
                "occurredAt": input.occurredAt as Any?, "captureTimeZoneID": input.captureTimeZoneID,
                "source": input.source.rawValue])
        }, key: { try required($0, "operationID") as UUID }, context: context)
        _ = try sync("GoalPeriod", records: state.snapshot.timeline.periods.map {
            ($0.activityID.uuidString + $0.range.start.description,
             ["activityID": $0.activityID, "activity": activities[$0.activityID.uuidString] as Any?,
              "startDay": $0.range.start.description, "endDayExclusive": $0.endDayExclusive.description,
              "cadence": $0.cadence.rawValue, "target": $0.target, "targetAppliedAt": $0.targetAppliedAt,
              "eligibility": $0.eligibility.rawValue, "closedAt": $0.closedAt as Any?])
        }, stringKey: {
            let id: UUID = try required($0, "activityID")
            let day: String = try required($0, "startDay")
            return id.uuidString + day
        }, context: context)
    }

    private static func activity(_ row: NSManagedObject) throws -> ActivitySnapshot {
        guard let cadence = Cadence(rawValue: try required(row, "cadence")) else {
            throw HabitError.storeUnavailable
        }
        let draft = try HabitDraft(name: required(row, "name"), symbolName: required(row, "symbolName"),
                                  cadence: cadence, target: integer(row, "initialTarget"))
        var value = try ActivitySnapshot(id: required(row, "id"), draft: draft,
                                        createdAt: required(row, "createdAt"),
                                        createdDay: CalendarDay(required(row, "createdDay")))
        value.trackingStartDay = try CalendarDay(required(row, "trackingStartDay"))
        value.trackingStartsAtMidnight = try required(row, "trackingStartsAtMidnight")
        value.effectiveTarget = try integer(row, "effectiveTarget")
        value.pendingTarget = (row.value(forKey: "pendingTarget") as? NSNumber)?.intValue
        if let day = row.value(forKey: "pendingTargetStartDay") as? String {
            value.pendingTargetStartDay = try CalendarDay(day)
        }
        return value
    }

    private static func activityFields(_ value: ActivitySnapshot) -> [String: Any?] {
        ["id": value.id, "name": value.name, "symbolName": value.symbolName,
         "cadence": value.cadence.rawValue, "createdAt": value.createdAt,
         "createdDay": value.createdDay.description, "trackingStartDay": value.trackingStartDay.description,
         "trackingStartsAtMidnight": value.trackingStartsAtMidnight, "initialTarget": value.initialTarget,
         "effectiveTarget": value.effectiveTarget, "pendingTarget": value.pendingTarget as Any?,
         "pendingTargetStartDay": value.pendingTargetStartDay?.description as Any?]
    }

    private static func period(_ row: NSManagedObject) throws -> GoalPeriodSnapshot {
        guard let cadence = Cadence(rawValue: try required(row, "cadence")),
              let eligibility = PeriodEligibility(rawValue: try required(row, "eligibility")) else {
            throw HabitError.storeUnavailable
        }
        var value = try GoalPeriodSnapshot(
            activityID: required(row, "activityID"), cadence: cadence,
            range: DayRange(start: CalendarDay(required(row, "startDay")),
                            end: CalendarDay(required(row, "endDayExclusive")).adding(days: -1)),
            target: integer(row, "target")
        )
        value.eligibility = eligibility
        value.closedAt = row.value(forKey: "closedAt") as? Date
        value.targetAppliedAt = try required(row, "targetAppliedAt")
        return value
    }

    private static func completion(_ row: NSManagedObject) throws -> CompletionSnapshot {
        try CompletionSnapshot(
            id: required(row, "id"), activityID: required(row, "activityID"),
            assignedDay: CalendarDay(required(row, "assignedDay")),
            occurredAt: row.value(forKey: "occurredAt") as? Date,
            captureTimeZoneID: required(row, "captureTimeZoneID"), createdAt: required(row, "createdAt"),
            source: source(row), operationID: required(row, "operationID"),
            wasTimeOrDateEdited: required(row, "wasTimeOrDateEdited")
        )
    }

    private static func source(_ row: NSManagedObject) throws -> CompletionSource {
        guard let source = CompletionSource(rawValue: try required(row, "source")) else {
            throw HabitError.storeUnavailable
        }
        return source
    }

    private static func rows(_ entity: String, _ context: NSManagedObjectContext) throws
        -> [NSManagedObject] {
        let result = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: entity))
        if ["Completion", "OperationReceipt", "GoalPeriod"].contains(entity) {
            for row in result {
                guard let activity = row.value(forKey: "activity") as? NSManagedObject,
                      let relatedID = activity.value(forKey: "id") as? UUID,
                      relatedID == row.value(forKey: "activityID") as? UUID else {
                    throw HabitError.storeUnavailable
                }
            }
        }
        return result
    }

    private static func required<T>(_ row: NSManagedObject, _ key: String) throws -> T {
        guard let value = row.value(forKey: key) as? T else { throw HabitError.storeUnavailable }
        return value
    }

    private static func integer(_ row: NSManagedObject, _ key: String) throws -> Int {
        let number: NSNumber = try required(row, key)
        return number.intValue
    }

    private static func set(_ fields: [String: Any?], on row: NSManagedObject) {
        for (key, value) in fields {
            let old = row.value(forKey: key) as? NSObject
            let new = value as? NSObject
            if old != new { row.setValue(value, forKey: key) }
        }
    }

    @discardableResult
    private static func sync(_ entity: String, records: [(String, [String: Any?])],
                             key: (NSManagedObject) throws -> UUID,
                             context: NSManagedObjectContext) throws -> [String: NSManagedObject] {
        try sync(entity, records: records, stringKey: { try key($0).uuidString }, context: context)
    }

    @discardableResult
    private static func sync(_ entity: String, records: [(String, [String: Any?])],
                             stringKey: (NSManagedObject) throws -> String,
                             context: NSManagedObjectContext) throws -> [String: NSManagedObject] {
        var existing: [String: NSManagedObject] = [:]
        for row in try rows(entity, context) { existing[try stringKey(row)] = row }
        var result: [String: NSManagedObject] = [:]
        for (key, fields) in records {
            let row = existing.removeValue(forKey: key)
                ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
            set(fields, on: row)
            result[key] = row
        }
        for row in existing.values { context.delete(row) }
        return result
    }
}
