package flavor

import adblocker.*
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import com.github.salomonbrys.kodein.*
import core.*
import filter.DashFilterBlacklist
import filter.DashFilterWhitelist
import notification.NotificationDashOn
import notification.displayNotification
import notification.hideNotification
import update.AboutDash
import update.UpdateDash

fun newFlavorModule(ctx: Context): Kodein.Module {
    return Kodein.Module {
        bind<List<Dash>>() with singleton {
            listOf(
                    UpdateDash(ctx).activate(true),
                    TunnelDashCountDropped(ctx).activate(true),
                    DashFilterBlacklist(ctx).activate(true),
                    DashFilterWhitelist(ctx).activate(true),
                    DashDns(lazy).activate(true),
                    NotificationDashOn(ctx).activate(true),
                    TunnelDashHostsCount(ctx).activate(true),
                    SocialShareCount(ctx).activate(true),
                    PatronDash(lazy).activate(false),
                    PatronAboutDash(lazy).activate(false),
                    DonateDash(lazy).activate(false),
                    NewsDash(lazy).activate(false),
                    FeedbackDash(lazy).activate(false),
                    FaqDash(lazy).activate(false),
                    ChangelogDash(lazy).activate(false),
                    AboutDash(ctx).activate(false),
                    CreditsDash(lazy).activate(false),
                    CtaDash(lazy).activate(false),
                    LoggerDash(ctx).activate(true)
            )
        }
        onReady {
            val s: Tunnel = instance()
            val ui: UiState = instance()
            // Show confirmation message to the user whenever notifications are enabled or disabled
            ui.notifications.doWhenChanged().then {
                if (ui.notifications()) {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_ENABLED)
                } else {
                    ui.infoQueue %= ui.infoQueue() + Info(InfoType.NOTIFICATIONS_DISABLED)
                }
            }

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
