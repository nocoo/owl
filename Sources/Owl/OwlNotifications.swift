import Foundation
import UserNotifications
import OwlCore

/// Manages macOS system notification banners for Owl alerts.
enum OwlNotifications {

    /// Request notification authorization from the user.
    static func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in
            // Best-effort: if denied, notifications simply won't appear.
        }
    }

    /// Post a system notification for an alert.
    @MainActor
    static func post(for alert: Alert) {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.description
        content.sound = alert.severity == .critical
            ? .defaultCritical
            : .default

        let request = UNNotificationRequest(
            identifier: "owl.alert.\(alert.detectorID).\(alert.timestamp.timeIntervalSince1970)",
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in
            // Best-effort delivery
        }
    }
}
