import Foundation
import UserNotifications

enum NotificationAuthorization: Sendable {
    case notDetermined, denied, authorized, provisional
}

protocol NotificationClient: Sendable {
    func pendingIDs() async -> Set<String>
    func remove(ids: Set<String>) async
    func add(_ request: PlannedNotification) async throws
    func authorization() async -> NotificationAuthorization
    func requestAuthorization() async throws -> Bool
}

struct SystemNotificationClient: NotificationClient {
    func pendingIDs() async -> Set<String> {
        Set(await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier))
    }

    func remove(ids: Set<String>) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(ids))
    }

    func add(_ request: PlannedNotification) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = "Time for your habit. Tap to view your progress."
        content.sound = .default
        content.userInfo = ["activityID": request.activityID.uuidString]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
        components.timeZone = .gmt
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: request.id, content: content, trigger: trigger))
    }

    func authorization() async -> NotificationAuthorization {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .authorized, .ephemeral: .authorized
        case .provisional: .provisional
        case .denied: .denied
        default: .notDetermined
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }
}
