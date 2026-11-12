import Foundation

struct PlannedNotification: Equatable, Sendable, Identifiable {
    let id: String
    let activityID: UUID
    let title: String
    let day: CalendarDay
    let slot: Int
    let fireDate: Date
}

enum NotificationPlanner {
    static func plan(snapshot: StoreSnapshot, at now: ClockReading) -> [PlannedNotification] {
        var projected = snapshot
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = now.timeZone
        var candidates: [PlannedNotification] = []
        for offset in 0..<28 {
            guard let day = try? now.localDay.adding(days: offset),
                  let clock = try? ClockReading(instant: max(now.instant, day.midnight(in: now.timeZone)), timeZone: now.timeZone),
                  (try? ReminderRules.advance(&projected, at: clock)) != nil else { continue }
            for activity in projected.timeline.activities {
                guard let config = projected.reminders[activity.id], config.isEnabled,
                      day >= activity.trackingStartDay,
                      let period = projected.timeline.periods.first(where: {
                          $0.activityID == activity.id && $0.range.contains(day)
                      }),
                      !GoalRules.progress(period: period, completions: snapshot.completions).isMet
                else { continue }
                let count = snapshot.completions.filter { $0.activityID == activity.id && $0.assignedDay == day }.count
                if activity.cadence == .weekly && count > 0 { continue }
                for (index, slot) in config.slots.enumerated() {
                    if activity.cadence == .daily && index < count { continue }
                    let components = DateComponents(hour: slot.effectiveMinute / 60, minute: slot.effectiveMinute % 60)
                    guard let fire = calendar.nextDate(after: day.midnight(in: now.timeZone).addingTimeInterval(-1),
                        matching: components, matchingPolicy: .nextTime, repeatedTimePolicy: .first),
                        fire > now.instant,
                        (try? ClockReading(instant: fire, timeZone: now.timeZone).localDay) == day else { continue }
                    candidates.append(PlannedNotification(
                        id: "habit.\(activity.id.uuidString).\(day).\(index).\(Int(fire.timeIntervalSince1970))",
                        activityID: activity.id, title: activity.name, day: day, slot: index, fireDate: fire))
                }
            }
        }
        candidates.sort {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            if $0.activityID != $1.activityID { return $0.activityID.uuidString < $1.activityID.uuidString }
            if $0.slot != $1.slot { return $0.slot < $1.slot }
            return $0.id < $1.id
        }
        return Array(candidates.prefix(60))
    }
}
