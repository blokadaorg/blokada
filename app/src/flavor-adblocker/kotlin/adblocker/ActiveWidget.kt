package adblocker

import android.app.Activity
import android.app.PendingIntent
import android.app.Service
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.IBinder
import android.util.Base64
import android.view.View
import android.widget.Button
import android.widget.CheckBox
import android.widget.RemoteViews
import android.widget.TextView
import com.github.salomonbrys.kodein.instance
import core.*
import gs.environment.inject
import gs.property.I18n
import gs.property.IWhen
import org.blokada.R
import tunnel.Events
import tunnel.Request
import java.nio.charset.Charset


val NEW_WIDGET = "NEW_WIDGET".newEventOf<WidgetData>()
val RESTORE_WIDGET = "RESTORE_WIDGET".newEventOf<WidgetRestoreData>()
val DELETE_WIDGET = "DELETE_WIDGET".newEventOf<IntArray>()


object WidgetRestoreData {
    var oldWidgetIds: IntArray = IntArray(0)
    var newWidgetIds: IntArray = IntArray(0)
}

class WidgetData {
    var id: Int = -1
    var host: Boolean = false
    var dns: Boolean = false
    var counter: Boolean = false
    var alpha: Int = 0

    override fun hashCode(): Int {
        return id
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as WidgetData

        if (id != other.id) return false

        return true
    }
}


class ActiveWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context?) {
        super.onEnabled(context)
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        super.onReceive(context, intent)
        if ((context != null) and (intent != null)) {
            if (intent?.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE) {
                val extras = intent.extras
                if (extras != null) {
                    val appWidgetId = extras.getInt(
                            AppWidgetManager.EXTRA_APPWIDGET_ID,
                            AppWidgetManager.INVALID_APPWIDGET_ID)
                    if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
                        return
                    }
                    if (extras.containsKey("changeBlokadaState")) {
                        val t: Tunnel = context!!.inject().instance()
                        context.ktx("activewidget").v("toggling enabled")
                        t.error %= false
                        t.enabled %= !t.enabled()
                    }
                }
            }
        }
    }

    override fun onRestored(context: Context?, oldWidgetIds: IntArray?, newWidgetIds: IntArray?) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
        val restoreData = WidgetRestoreData
        restoreData.oldWidgetIds = oldWidgetIds ?: IntArray(0)
        restoreData.newWidgetIds = newWidgetIds ?: IntArray(0)
        context?.ktx()?.emit(RESTORE_WIDGET, restoreData)
    }

    override fun onDeleted(context: Context?, appWidgetIds: IntArray?) {
        super.onDeleted(context, appWidgetIds)
        context!!.ktx().emit(DELETE_WIDGET, appWidgetIds ?: IntArray(0))
    }

    override fun onDisabled(context: Context?) {
        super.onDisabled(context)
        val serviceIntent = Intent(context?.applicationContext,
                UpdateWidgetService::class.java)
        context?.stopService(serviceIntent)
    }
}

class UpdateWidgetService : Service() {

    private val onBlockedEvent = { request: Request -> if (request.blocked) onBlocked(request.domain) }
    private val onNewWidgetEvent = { data: WidgetData -> onNewWidget(data) }
    private val onRestoreEvent = { restoreData: WidgetRestoreData -> onRestoreWidget(restoreData) }
    private val onDeleteEvent = { appWidgetIds: IntArray -> onDeleteWidget(appWidgetIds) }
    private var onTunnelStateEvent: IWhen? = null
    private var onDNSEvent: IWhen? = null
    private var widgetList: LinkedHashSet<WidgetData> = LinkedHashSet(5)

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if(widgetList.isEmpty()) {
            val pref = this.getSharedPreferences("widgets", Context.MODE_PRIVATE)

            val appWidgetManager = AppWidgetManager.getInstance(this)
            val thisWidget = ComponentName(this, ActiveWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            widgetIds.forEach {
                if (pref.contains("widget-$it")) {
                    val widgetConf = pref.getInt("widget-$it", 0)
                    val data = WidgetData()
                    data.id = it
                    data.alpha = widgetConf and 0xff
                    data.counter = (widgetConf and 0x100) > 0
                    data.host = (widgetConf and 0x200) > 0
                    data.dns = (widgetConf and 0x400) > 0
                    widgetList.add(data)
                    setWidget(data)
                } else {
                    this.ktx().v("widget not found!")
                    val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
                    remoteViews.setTextViewText(R.id.widget_counter, "ERROR")
                    remoteViews.setTextViewText(R.id.widget_host, "ERROR")
                    remoteViews.setTextViewText(R.id.widget_dns, "ERROR")
                    appWidgetManager.partiallyUpdateAppWidget(it, remoteViews)
                }
            }

            this.ktx().on(NEW_WIDGET, onNewWidgetEvent)

            this.ktx().on(RESTORE_WIDGET, onRestoreEvent)

            this.ktx().on(DELETE_WIDGET, onDeleteEvent)

            val t: Tunnel = this.inject().instance()
            val droppedlist = t.tunnelRecentDropped()
            if (droppedlist.isEmpty()) {
                onBlocked("")
            } else {
                onBlocked(droppedlist.last())
            }
            this.ktx().on(Events.REQUEST, onBlockedEvent)

            onTunnelStateChanged()
            onTunnelStateEvent = t.tunnelState.doOnUiWhenChanged(withInit = true).then {
                onTunnelStateChanged()
            }

            onDnsChanged()
            val d: Dns = this.inject().instance()
            onDNSEvent = d.dnsServers.doOnUiWhenChanged(withInit = true).then {
                onDnsChanged()
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        this.ktx().cancel(Events.REQUEST, onBlockedEvent)
        this.ktx().cancel(NEW_WIDGET, onNewWidgetEvent)
        this.ktx().cancel(RESTORE_WIDGET, onRestoreEvent)
        this.ktx().cancel(DELETE_WIDGET, onDeleteEvent)
        val t: Tunnel = this.inject().instance()
        t.tunnelState.cancel(onTunnelStateEvent)
        val d: Dns = this.inject().instance()
        d.dnsServers.cancel(onDNSEvent)
        super.onDestroy()
    }

    private fun onNewWidget(data: WidgetData) {
        val pref = this.getSharedPreferences("widgets", Context.MODE_PRIVATE)
        widgetList.add(data)
        var widgetConf = data.alpha and 0xff
        if (data.counter) {
            widgetConf = widgetConf or 0x100
        }
        if (data.host) {
            widgetConf = widgetConf or 0x200
        }
        if (data.dns) {
            widgetConf = widgetConf or 0x400
        }
        pref.edit().putInt("widget-${data.id}", widgetConf).apply()
        setWidget(data)
        if (data.host or data.counter) {
            val t: Tunnel = this.inject().instance()
            val droppedlist = t.tunnelRecentDropped.invoke()
            if (droppedlist.isEmpty()) {
                onBlocked("")
            } else {
                onBlocked(droppedlist.last())
            }
        }
        if (data.dns) {
            onDnsChanged()
        }
        onTunnelStateChanged()
    }

    private fun onRestoreWidget(restoreData: WidgetRestoreData) {
        val pref = this.getSharedPreferences("widgets", Context.MODE_PRIVATE)
        val prefEdit = pref.edit()

        for ((index, oldId) in restoreData.oldWidgetIds.withIndex()) {
            if (pref.contains("widget-$oldId")) {
                val widgetConf = pref.getInt("widget-$oldId", 0)
                prefEdit.remove("widget-$oldId")
                prefEdit.putInt("widget-" + restoreData.newWidgetIds[index], widgetConf)
                (widgetList.find { wd -> wd.id == oldId })?.id = restoreData.newWidgetIds[index]
            } else {
                this.ktx().v("old widget id not found!")
            }
        }
        prefEdit.apply()
    }

    private fun onDeleteWidget(appWidgetIds: IntArray) {
        val pref = this.getSharedPreferences("widgets", Context.MODE_PRIVATE)
        val prefEdit = pref.edit()
        appWidgetIds.forEach { appWidgetId ->
            val wd = widgetList.find { wd -> wd.id == appWidgetId }
            widgetList.remove(wd)
            if (pref.contains("widget-" + wd?.id)) {
                prefEdit.remove("widget-" + wd?.id)
            }
        }
        prefEdit.apply()
    }

    private fun onTunnelStateChanged() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        val thisWidget = ComponentName(this, ActiveWidgetProvider::class.java)
        val t: Tunnel = this.inject().instance()
        when (t.tunnelState()) {
            TunnelState.ACTIVE ->
                remoteViews.setInt(R.id.widget_active, "setColorFilter", color(active = true, waiting = false))
            TunnelState.ACTIVATING ->
                remoteViews.setInt(R.id.widget_active, "setColorFilter", color(active = true, waiting = true))
            TunnelState.DEACTIVATING ->
                remoteViews.setInt(R.id.widget_active, "setColorFilter", color(active = false, waiting = true))
            TunnelState.DEACTIVATED, TunnelState.INACTIVE ->
                remoteViews.setInt(R.id.widget_active, "setColorFilter", color(active = false, waiting = false))
        }

        appWidgetManager.partiallyUpdateAppWidget(appWidgetManager.getAppWidgetIds(thisWidget), remoteViews)

        appWidgetManager.getAppWidgetIds(thisWidget).forEach {
            val intent = Intent(this, ActiveWidgetProvider::class.java)
            intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, it)
            intent.putExtra("changeBlokadaState", true)
            val pendingIntent = PendingIntent.getBroadcast(this.applicationContext,
                    0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            remoteViews.setOnClickPendingIntent(R.id.widget_active, pendingIntent)
            appWidgetManager.partiallyUpdateAppWidget(it, remoteViews)
        }
    }

    private fun onDnsChanged() {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        val d: Dns = this.inject().instance()
        val i18n: I18n = this.inject().instance()
        val dc = d.choices().find { it.active }
        val name = when {
            dc == null -> this.getString(R.string.dns_text_none)
            dc.servers.isEmpty() -> this.getString(R.string.dns_text_none)
            dc.id.startsWith("custom-dns:") ->  Base64.decode(dc.id.removePrefix("custom-dns:"), Base64.NO_WRAP).toString(Charset.defaultCharset())
            else -> i18n.localisedOrNull("dns_${dc.id}_name") ?: dc.comment ?: dc.id.capitalize()
        }

        remoteViews.setTextViewText(R.id.widget_dns, name)
        appWidgetManager.partiallyUpdateAppWidget(widgetList.mapNotNull { e -> if (e.dns) e.id else null }.toIntArray(), remoteViews)
    }

    private fun onBlocked(host: String) {
        val appWidgetManager = AppWidgetManager.getInstance(this)
        var remoteViews = RemoteViews(this.packageName, R.layout.widget_active)

        val t: Tunnel = this.inject().instance()
        when (t.tunnelDropCount()) {
            in 0..9999 -> remoteViews.setTextViewText(R.id.widget_counter, t.tunnelDropCount().toString())
            in 10000..99999 -> remoteViews.setTextViewText(R.id.widget_counter, String.format("%.1fk", t.tunnelDropCount() / 1000.0))
            in 100000..9999999 -> remoteViews.setTextViewText(R.id.widget_counter, String.format("%.2fm", t.tunnelDropCount() / 1000000.0))
            else -> remoteViews.setTextViewText(R.id.widget_counter, String.format("%dm", t.tunnelDropCount() / 1000000))
        }

        appWidgetManager.partiallyUpdateAppWidget(widgetList.mapNotNull { e -> if (e.counter) e.id else null }.toIntArray(), remoteViews)

        remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        remoteViews.setTextViewText(R.id.widget_host, host)

        appWidgetManager.partiallyUpdateAppWidget(widgetList.mapNotNull { e -> if (e.host) e.id else null }.toIntArray(), remoteViews)
    }

    private fun setWidget(data: WidgetData) {

        val appWidgetManager = AppWidgetManager.getInstance(this)
        val views = RemoteViews(this.packageName,
                R.layout.widget_active)
        if (data.counter) {
            views.setViewVisibility(R.id.widget_counter, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_counter, View.GONE)
        }

        if (data.host) {
            views.setViewVisibility(R.id.widget_host, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_host, View.GONE)
        }

        if (data.dns) {
            views.setViewVisibility(R.id.widget_dns, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_dns, View.GONE)
        }

//        views.setInt(R.id.widget_root, "setBackgroundColor", data.alpha shl 24 or 0x00262626)

        val intent = Intent(this, ActiveWidgetProvider::class.java)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, data.id)
        intent.putExtra("changeBlokadaState", true)
        val pendingIntent = PendingIntent.getBroadcast(this.applicationContext,
                0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
        views.setOnClickPendingIntent(R.id.widget_active, pendingIntent)

        appWidgetManager.updateAppWidget(data.id, views)
    }

    private fun color(active: Boolean, waiting: Boolean): Int {
        return when {
            waiting -> resources.getColor(R.color.colorLogoWaiting)
            active -> resources.getColor(android.R.color.transparent)
            else -> resources.getColor(R.color.colorLogoInactive)
        }
    }
}

class ConfigWidgetActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.view_config_widget)
        var appWidgetId = 0
        val intent = intent
        val extras = intent.extras
        if (extras != null) {
            appWidgetId = extras.getInt(
                    AppWidgetManager.EXTRA_APPWIDGET_ID,
                    AppWidgetManager.INVALID_APPWIDGET_ID)
        }
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
        }


        val preview = findViewById<View>(R.id.widget_cv_preview)

        preview.findViewById<TextView>(R.id.widget_counter).text = "17835"
        preview.findViewById<TextView>(R.id.widget_host).text = "evil-tracker.com"
        preview.findViewById<TextView>(R.id.widget_dns).text = "1.1.1.1"

        var cb = findViewById<CheckBox>(R.id.widget_cv_show_counter)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val tv = preview.findViewById<TextView>(R.id.widget_counter)
            if (isChecked) {
                tv.visibility = View.VISIBLE

            } else {
                tv.visibility = View.GONE
            }
        }

        cb = findViewById(R.id.widget_cv_show_host)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val host = preview.findViewById<TextView>(R.id.widget_host)
            if (isChecked) {
                host.visibility = View.VISIBLE
            } else {
                host.visibility = View.GONE
            }
        }

        cb = findViewById(R.id.widget_cv_show_dns)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val dns = preview.findViewById<TextView>(R.id.widget_dns)
            if (isChecked) {
                dns.visibility = View.VISIBLE
            } else {
                dns.visibility = View.GONE
            }
        }

//        val sb = findViewById<SeekBar>(R.id.widget_cv_alpha)
//        sb.setOnSeekBarChangeListener(object : OnSeekBarChangeListener {
//
//            override fun onStopTrackingTouch(seekBar: SeekBar) {
//            }
//
//            override fun onStartTrackingTouch(seekBar: SeekBar) {
//            }
//
//            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
//                (preview as LinearLayout).background.alpha = progress
//            }
//        })

        val btn = findViewById<Button>(R.id.widget_cv_okay)
        btn.setOnClickListener {
            val data = WidgetData()

            data.counter = findViewById<CheckBox>(R.id.widget_cv_show_counter).isChecked
            data.host = findViewById<CheckBox>(R.id.widget_cv_show_host).isChecked
            data.dns = findViewById<CheckBox>(R.id.widget_cv_show_dns).isChecked
//            data.alpha = findViewById<SeekBar>(R.id.widget_cv_alpha).progress
            data.id = appWidgetId

            ktx().emit(NEW_WIDGET, data)

            val serviceIntent = Intent(this.applicationContext,
                    UpdateWidgetService::class.java)
            this.startService(serviceIntent)

            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }
}


