import Foundation
import UserNotifications

final class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendLowBattery(level: Int, budName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Low Battery"
        content.body = "\(budName) at \(level)%"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-battery-\(budName)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
