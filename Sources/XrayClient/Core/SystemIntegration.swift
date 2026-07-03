import Foundation
import ServiceManagement
import UserNotifications

/// Manages the "launch at login" state via the modern SMAppService API
/// (macOS 13+). Registering adds the app as a login item; unregistering removes
/// it. Requires the app to be a real bundle (it is, via package-app.sh).
enum LoginItem {

    /// Whether the app is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Applies the desired state. Returns true on success. Failures are silent
    /// (e.g. when running an unbundled `swift run` binary, where SMAppService
    /// has nothing to register).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            return false
        }
    }
}

/// Thin wrapper around UNUserNotificationCenter for connection status alerts.
@MainActor
enum NotificationManager {

    /// Asks the user for permission (no-op if already decided).
    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    /// Posts a local notification. Silently does nothing if not authorized.
    static func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
