import Foundation
import Flutter
import UIKit

class StartupContext {
    static let shared = StartupContext()
    static let firstFlutterFrameRenderedNotification = Notification.Name("StartupContext.firstFlutterFrameRendered")

    private let channelName = "org.blokada/startup"
    private var currentContext: [String: Any?] = ["reason": "foregroundInteractive"]
    private(set) var hasSeenFirstFlutterFrame = false

    func attach(messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: messenger
        )

        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "consumeLaunchContext":
                self.normalizeForUiSceneIfNeeded()
                result(self.currentContext)
                self.currentContext = ["reason": "foregroundInteractive"]
            case "firstFrameRendered":
                self.markFirstFlutterFrameRendered()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func markFirstFlutterFrameRendered() {
        guard !hasSeenFirstFlutterFrame else {
            return
        }

        hasSeenFirstFlutterFrame = true
        NotificationCenter.default.post(name: StartupContext.firstFlutterFrameRenderedNotification, object: nil)
    }

    func normalizeForUiSceneIfNeeded() {
        guard let reason = currentContext["reason"] as? String else {
            return
        }

        if reason == "backgroundTask" && UIApplication.shared.applicationState != .background {
            currentContext = ["reason": "foregroundInteractive"]
        }
    }

    func markForegroundInteractive() {
        currentContext = ["reason": "foregroundInteractive"]
    }

    func markNotificationTap(notificationId: String) {
        currentContext = [
            "reason": "foregroundInteractive",
            "notificationId": notificationId,
        ]
    }

    func markBackgroundTask(payload: String, eventType: String?, source: String = "fcm") {
        currentContext = [
            "reason": "backgroundTask",
            "backgroundSource": source,
            "payload": payload,
            "fcmEventType": eventType,
        ]
    }
}
