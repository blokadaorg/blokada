import Foundation
import Flutter
import UIKit

class StartupContext {
    static let shared = StartupContext()

    private let channelName = "org.blokada/startup"
    private var currentContext: [String: Any?] = ["reason": "foregroundInteractive"]

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
            default:
                result(FlutterMethodNotImplemented)
            }
        }
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
