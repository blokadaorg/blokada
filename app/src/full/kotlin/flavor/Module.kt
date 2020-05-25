package flavor

import adblocker.ActiveWidgetProvider
import adblocker.ForegroundStartService
import adblocker.ListWidgetProvider
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
import core.updateControllswitchWidgets
import notification.FilteredNotification
import notification.notificationMain
import tunnel.RequestLog
import tunnel.LogConfig
import tunnel.RequestUpdate
import tunnel.TunnelEvents.REQUEST_UPDATE

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        onReady {
            val s: Tunnel = instance()
            val ui: UiState = instance()

            // Display notifications for dropped
            val updateNotification = { ru: RequestUpdate? ->
                if (ru?.oldState == null) { //TODO ru == null || ru.oldState == null
                    if (RequestLog.lastBlockedDomain == "") {
                        notificationMain.cancel(FilteredNotification(""))
                    } else if (ui.notifications()) {
                        notificationMain.show(FilteredNotification(RequestLog.lastBlockedDomain,
                                counter = RequestLog.dropCount))
                    }
                    updateListWidget(ctx)
                }
                Unit
            }
            ctx.ktx().on(REQUEST_UPDATE, updateNotification)
            updateNotification(null)

            s.enabled.doWhenChanged().then{
                updateListWidget(ctx)
                updateControllswitchWidgets(ctx)
            }

            s.tunnelState.doWhenChanged().then{
                updateListWidget(ctx)
                updateControllswitchWidgets(ctx)
            }

            updateListWidget(ctx)
            updateControllswitchWidgets(ctx)

            // Hide notification when disabled
            ui.notifications.doOnUiWhenSet().then {
                notificationMain.cancel(FilteredNotification(""))
            }

            val config = core.get(LogConfig::class.java)
            val wm: AppWidgetManager = AppWidgetManager.getInstance(ctx)
            val ids = wm.getAppWidgetIds(ComponentName(ctx, ActiveWidgetProvider::class.java))
            if(((ids != null) and (ids.isNotEmpty())) or config.logActive) {
                val serviceIntent = Intent(ctx.applicationContext,
                        ForegroundStartService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ctx.startForegroundService(serviceIntent)
                } else {
                    ctx.startService(serviceIntent)
                }
            }
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
