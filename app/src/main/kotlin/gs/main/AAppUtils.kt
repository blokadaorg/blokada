package gs.main

import android.annotation.TargetApi
import android.app.AlarmManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.github.salomonbrys.kodein.instance
import gs.environment.Journal
import gs.environment.inject


internal fun registerUncaughtExceptionHandler(ctx: android.content.Context) {
    val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
    Thread.setDefaultUncaughtExceptionHandler { thread, ex ->
        gs.main.restartApplicationThroughService(ctx, 2000)
//        defaultHandler.uncaughtException(thread, ex)
        System.exit(2)
    }
}

private fun restartApplicationThroughService(ctx: android.content.Context, delayMillis: Int) {
    val alarm: android.app.AlarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    val restartIntent = android.content.Intent(ctx, RestartService::class.java)
    val intent = android.app.PendingIntent.getService(ctx, 0, restartIntent, 0)
    alarm.set(android.app.AlarmManager.RTC, System.currentTimeMillis() + delayMillis, intent)
}

@TargetApi(24)
internal fun getPreferredLocales(): List<java.util.Locale> {
    val cfg = android.content.res.Resources.getSystem().configuration
    return try {
        // Android, a custom list type that is not an iterable. Just wow.
        val locales = cfg.locales
        (0..locales.size() - 1).map { locales.get(it) }
    } catch (t: Throwable) { listOf(cfg.locale) }
}

class RestartService : Service() {

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val j: Journal = inject().instance()
        j.log("RestartService start command")
        return Service.START_STICKY;
    }

}
