package adblocker

import android.app.Service
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.IBinder
import kotlinx.coroutines.experimental.runBlocking
import notification.KeepAliveNotification
import notification.notificationMain


class ForegroundStartService: Service(){

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notification = KeepAliveNotification()
            val n = runBlocking { notificationMain.getNotification(notification).await() }
            startForeground(notification.id, n)
        }

        var serviceIntent = Intent(this.applicationContext,
                RequestLogger::class.java)
        serviceIntent.putExtra("load_on_start", true)
        this.startService(serviceIntent)

        val wm: AppWidgetManager = AppWidgetManager.getInstance(this)
        val ids = wm.getAppWidgetIds(ComponentName(this, ActiveWidgetProvider::class.java))
        if((ids != null) and (ids.isNotEmpty())){
            serviceIntent = Intent(this.applicationContext,
                    UpdateWidgetService::class.java)
            this.startService(serviceIntent)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }

        stopSelf()
        return START_NOT_STICKY
    }

}
