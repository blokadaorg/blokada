package flavor

import adblocker.ActiveWidgetProvider
import adblocker.ForegroundStartService
import adblocker.ListWidgetProvider
import adblocker.LoggerConfigPersistence
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import com.github.salomonbrys.kodein.Kodein
import com.github.salomonbrys.kodein.instance
import core.Tunnel
import core.UiState
import core.ktx
import notification.displayNotification
import notification.hideNotification

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        onReady {
            val s: Tunnel = instance()
            val ui: UiState = instance()

            // Display notifications for dropped
            s.tunnelRecentDropped.doOnUiWhenSet().then {
                if (s.tunnelRecentDropped().isEmpty()) hideNotification(ctx)
                else if (ui.notifications()) displayNotification(ctx, s.tunnelRecentDropped().last())
            }

            s.tunnelRecentDropped.doWhenChanged().then{
                updateListWidget(ctx)
            }
            s.enabled.doWhenChanged().then{
                updateListWidget(ctx)
            }
            updateListWidget(ctx)

            // Hide notification when disabled
            ui.notifications.doOnUiWhenSet().then {
                hideNotification(ctx)
            }

            val persistenceConfig = LoggerConfigPersistence()
            val config = persistenceConfig.load(ctx.ktx())
            val wm: AppWidgetManager = AppWidgetManager.getInstance(ctx)
            val ids = wm.getAppWidgetIds(ComponentName(ctx, ActiveWidgetProvider::class.java))
            if(((ids != null) and (ids.isNotEmpty())) or config.active) {
                val serviceIntent = Intent(ctx.applicationContext,
                        ForegroundStartService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(serviceIntent)
                } else {
                    ctx.startService(serviceIntent)
                }
            }

            // Initialize default values for properties that need it (async)
            s.tunnelDropCount {}
        }


    }
}

fun updateListWidget(ctx: Context){
    val updateIntent = Intent(ctx.applicationContext, ListWidgetProvider::class.java)
    updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
    val widgetManager = AppWidgetManager.getInstance(ctx)
    val ids = widgetManager.getAppWidgetIds(ComponentName(ctx, ListWidgetProvider::class.java))
    updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
    ctx.sendBroadcast(updateIntent)
}
