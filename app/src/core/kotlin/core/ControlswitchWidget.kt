package core


import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import blocka.BlockaVpnState
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import notification.ANotificationsToggleService
import notification.NotificationsToggleSeviceSettings
import org.blokada.R
import tunnel.TunnelConfig

abstract class ControlswitchWidgetProvider : AppWidgetProvider() {

    abstract val icon: Int
    abstract val requestCode: Int
    abstract val changedSetting: NotificationsToggleSeviceSettings

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val remoteViews = RemoteViews(context!!.packageName,
                R.layout.widget_controlswitch)

        remoteViews.setImageViewResource(R.id.widget_icon, icon)
        val intent = Intent(context, ANotificationsToggleService::class.java)
        intent.putExtra("new_state", !checkState(context))
        intent.putExtra("setting", changedSetting)
        remoteViews.setOnClickPendingIntent(R.id.widget_icon, PendingIntent.getService(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT))
        if (checkState(context)) {
            remoteViews.setInt(R.id.widget_icon, "setColorFilter", color(context, active = true, waiting = false))
        } else {
            remoteViews.setInt(R.id.widget_icon, "setColorFilter", color(context, active = false, waiting = false))
        }
        appWidgetManager?.partiallyUpdateAppWidget(appWidgetIds, remoteViews)
    }

    private fun color(ctx: Context, active: Boolean, waiting: Boolean): Int {
        return when {
            waiting -> ctx.resources.getColor(R.color.colorLogoWaiting)
            active -> ctx.resources.getColor(android.R.color.transparent)
            else -> ctx.resources.getColor(R.color.colorLogoInactive)
        }
    }

    abstract fun checkState(ctx: Context): Boolean
}

class TunnelSwitchWidgetProvider : ControlswitchWidgetProvider() {
    override val icon = R.drawable.ic_blokada
    override val changedSetting = NotificationsToggleSeviceSettings.TUNNEL
    override val requestCode: Int = 1727314487
    override fun checkState(ctx: Context): Boolean {
        val t: Tunnel = ctx.inject().instance()
        return t.enabled()
    }
}

class AdblockingSwitchWidgetProvider : ControlswitchWidgetProvider() {
    override val icon = R.drawable.ic_block
    override val changedSetting = NotificationsToggleSeviceSettings.ADBLOCKING
    override val requestCode: Int = -238650205
    override fun checkState(ctx: Context): Boolean {
        val config = get(TunnelConfig::class.java)
        return config.adblocking
    }
}

class DnsSwitchWidgetProvider : ControlswitchWidgetProvider() {
    override val icon = R.drawable.ic_server
    override val changedSetting = NotificationsToggleSeviceSettings.DNS
    override val requestCode: Int = 1534783645
    override fun checkState(ctx: Context): Boolean {
        val dns: Dns = ctx.inject().instance()
        return dns.enabled()
    }
}

class VpnSwitchWidgetProvider : ControlswitchWidgetProvider() {
    override val icon = R.drawable.ic_share
    override val changedSetting = NotificationsToggleSeviceSettings.VPN
    override val requestCode: Int = -1541302845
    override fun checkState(ctx: Context): Boolean {
        val config = get(BlockaVpnState::class.java)
        return config.enabled
    }
}

fun updateControllswitchWidgets(ctx: Context){
    arrayOf(
        TunnelSwitchWidgetProvider::class.java,
        AdblockingSwitchWidgetProvider::class.java,
        DnsSwitchWidgetProvider::class.java,
        VpnSwitchWidgetProvider::class.java
    ).forEach { widgettype ->
        val updateIntent = Intent(ctx.applicationContext, widgettype)
        updateIntent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        val widgetManager = AppWidgetManager.getInstance(ctx)
        val ids = widgetManager.getAppWidgetIds(ComponentName(ctx, widgettype))
        updateIntent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        ctx.sendBroadcast(updateIntent)

    }
}
