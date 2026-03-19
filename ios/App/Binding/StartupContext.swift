import Foundation
import Flutter

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
                result(self.currentContext)
                self.currentContext = ["reason": "foregroundInteractive"]
            default:
                result(FlutterMethodNotImplemented)
            }
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
