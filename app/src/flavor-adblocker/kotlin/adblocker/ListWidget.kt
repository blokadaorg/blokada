package adblocker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import com.github.salomonbrys.kodein.instance
import core.Tunnel
import gs.environment.inject
import notification.ANotificationsToggleService
import org.blokada.R
import android.widget.RemoteViews


class ListWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val remoteViews = RemoteViews(context!!.packageName,
                R.layout.view_list_widget)
        val t: Tunnel = context.inject().instance()

        remoteViews.setTextViewText(R.id.widget_list_title, context.resources.getString(R.string.notification_keepalive_title, t.tunnelDropCount()))
        remoteViews.setTextViewText(R.id.widget_list_text, context.getString(R.string.notification_keepalive_content, t.tunnelRecentDropped().lastOrNull()
                ?: ""))

        var domainList = ""
        val duplicates = ArrayList<String>(0)
        t.tunnelRecentDropped().asReversed().forEach { s ->
            if (!duplicates.contains(s)) {
                duplicates.add(s)
                domainList += s + '\n'
            }
        }
        remoteViews.setTextViewText(R.id.widget_list_message, domainList)

        val intent = Intent(context, ANotificationsToggleService::class.java)
        intent.putExtra("new_state", !t.enabled())
        remoteViews.setOnClickPendingIntent(R.id.widget_list_button, PendingIntent.getService(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT))
        if (t.enabled()) {
            remoteViews.setTextViewText(R.id.widget_list_button, "Deactivate")
        } else {
            remoteViews.setTextViewText(R.id.widget_list_button, "Activate")
        }
        appWidgetManager?.updateAppWidget(appWidgetIds, remoteViews)
    }
}
