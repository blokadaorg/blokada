package service

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import utils.Logger

object StartupContextService {
    private const val channelName = "org.blokada/startup"

    private var currentContext: HashMap<String, Any?> = foregroundInteractive()

    @Volatile
    var hasSeenFirstFlutterFrame: Boolean = false
        private set

    private val firstFrameListeners = mutableListOf<() -> Unit>()

    fun attach(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, channelName)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunchContext" -> {
                    result.success(HashMap(currentContext))
                    currentContext = foregroundInteractive()
                }
                "firstFrameRendered" -> {
                    markFirstFlutterFrameRendered()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Signals that Flutter has rendered its first frame. Idempotent — additional
     * calls after the first are no-ops. Listeners registered via
     * [addFirstFlutterFrameListener] are dispatched once, outside the lock.
     */
    fun markFirstFlutterFrameRendered() {
        val toNotify: List<() -> Unit>
        synchronized(this) {
            if (hasSeenFirstFlutterFrame) return
            hasSeenFirstFlutterFrame = true
            toNotify = firstFrameListeners.toList()
            firstFrameListeners.clear()
        }
        Logger.v("StartupContext", "First Flutter frame rendered")
        toNotify.forEach { listener ->
            try {
                listener()
            } catch (e: Throwable) {
                Logger.e("StartupContext", "First-frame listener failed: $e")
            }
        }
    }

    /**
     * Registers a one-shot listener for the first Flutter frame. If the frame has
     * already been reported the listener is invoked synchronously. Otherwise it
     * runs once on whichever thread calls [markFirstFlutterFrameRendered], outside
     * the internal lock.
     */
    fun addFirstFlutterFrameListener(listener: () -> Unit) {
        val invokeNow = synchronized(this) {
            if (hasSeenFirstFlutterFrame) {
                true
            } else {
                firstFrameListeners.add(listener)
                false
            }
        }
        if (invokeNow) listener()
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
