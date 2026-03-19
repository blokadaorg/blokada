package service

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object StartupContextService {
    private const val channelName = "org.blokada/startup"

    private var currentContext: HashMap<String, Any?> = foregroundInteractive()

    fun attach(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, channelName)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunchContext" -> {
                    result.success(HashMap(currentContext))
                    currentContext = foregroundInteractive()
                }
                else -> result.notImplemented()
            }
        }
    }

    fun markForegroundInteractive() {
        currentContext = foregroundInteractive()
    }

    fun markNotificationTap(notificationId: String) {
        currentContext = hashMapOf(
            "reason" to "foregroundInteractive",
            "notificationId" to notificationId,
        )
    }

    fun markBackgroundTask(payload: String, eventType: String?, source: String = "fcm") {
        currentContext = hashMapOf(
            "reason" to "backgroundTask",
            "backgroundSource" to source,
            "payload" to payload,
            "fcmEventType" to eventType,
        )
    }

    private fun foregroundInteractive(): HashMap<String, Any?> {
        return hashMapOf("reason" to "foregroundInteractive")
    }
}
