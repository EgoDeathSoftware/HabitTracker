import Foundation
import UserNotifications

final class NotificationNavigation: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = NotificationNavigation()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let rawID = response.notification.request.content.userInfo["activityID"] as? String
        Task { @MainActor in
            defer { completionHandler() }
            guard let rawID, let id = UUID(uuidString: rawID) else { return }
            let environment = AppEnvironment.shared
            await environment.openNotification(activityID: id)
        }
    }
}
