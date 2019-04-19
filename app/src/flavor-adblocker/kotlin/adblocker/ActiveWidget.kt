package adblocker

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.appwidget.AppWidgetProvider
import android.content.Context
import com.github.salomonbrys.kodein.instance
import gs.environment.inject
import org.blokada.R
import tunnel.Events
import android.content.ComponentName
import android.app.Service
import android.os.Bundle
import android.os.IBinder
import android.view.View
import android.widget.*
import android.widget.LinearLayout
import android.widget.SeekBar
import android.widget.SeekBar.OnSeekBarChangeListener
import core.*
import gs.property.I18n
import gs.property.IProperty
import gs.property.IWhen
import tunnel.Main


class ActiveWidgetProvider : AppWidgetProvider() {

    override fun onEnabled(context: Context?) {
        super.onEnabled(context)
        val serviceIntent = Intent(context?.applicationContext,
                UpdateWidgetService::class.java)
        context?.startService(serviceIntent)
    }

    override fun onUpdate(context: Context?, appWidgetManager: AppWidgetManager?, appWidgetIds: IntArray?) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        //enabled %=
    }

    override fun onRestored(context: Context?, oldWidgetIds: IntArray?, newWidgetIds: IntArray?) {
        super.onRestored(context, oldWidgetIds, newWidgetIds)
    }

    override fun onDisabled(context: Context?) {
        super.onDisabled(context)
        val serviceIntent = Intent(context?.applicationContext,
                UpdateWidgetService::class.java)
        context?.stopService(serviceIntent)
    }

}

class WidgetData{
    var id: Int = -1
    var host: Boolean = false
    var dns: Boolean = false
    var counter: Boolean = false
}

class UpdateWidgetService : Service() { //TODO: kill Service if device is locked; Impact battery?

    private val onBlockedEvent = { host: String -> update(host)}
    var onDnsEvent: IWhen? = null
    var widgetList: List<WidgetData> = List(0) {WidgetData()}

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    override fun onStartCommand(intent: Intent, flags: Int, startId: Int): Int {
        this.ktx().on(Events.BLOCKED, onBlockedEvent)


        val t: Tunnel = this.inject().instance()
        val droppedlist = t.tunnelRecentDropped.invoke()
        if(droppedlist.isEmpty()){
            update("")
        }else{
            update(droppedlist.last())
        }

        t.tunnelState.doWhenChanged().then{
            onTunnelStateChanged()
        }

        val d: Dns = this.inject().instance()
        onDnsEvent = d.dnsServers.doWhenChanged().then {
            onDnsChanged()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        this.ktx().cancel(Events.BLOCKED, onBlockedEvent)

        super.onDestroy()
    }

    private fun onTunnelStateChanged(){
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        val thisWidget = ComponentName(this, ActiveWidgetProvider::class.java)
        val t: Tunnel = this.inject().instance()
        remoteViews.setInt(R.id.widget_active,"setColorFilter",color(active = true, waiting = false))
        when(t.tunnelState.invoke()){
            TunnelState.ACTIVE ->
                remoteViews.setInt(R.id.widget_active,"setColorFilter",color(active = true, waiting = false))
            TunnelState.ACTIVATING ->
                remoteViews.setInt(R.id.widget_active,"setColorFilter",color(active = true, waiting = false))
            TunnelState.DEACTIVATING ->
                remoteViews.setInt(R.id.widget_active,"setColorFilter",color(active = false, waiting = true))
            TunnelState.DEACTIVATED, TunnelState.INACTIVE ->
                remoteViews.setInt(R.id.widget_active,"setColorFilter",color(active = false, waiting = false))
        }
        appWidgetManager.updateAppWidget(thisWidget, remoteViews)
    }

    private fun onDnsChanged(){
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        val thisWidget = ComponentName(this, ActiveWidgetProvider::class.java)
        val d: Dns = this.inject().instance()
        val i18n: I18n = this.inject().instance()
        val dc = d.choices.invoke().find { it.active }
        val name = when {
            dc == null -> this.getString(R.string.dns_text_none)
            dc.servers.isEmpty() -> this.getString(R.string.dns_text_none)
            dc.id.startsWith("custom") -> printServers(dc.servers)
            else -> i18n.localisedOrNull("dns_${dc.id}_name") ?: dc.id.capitalize()
        }

        remoteViews.setTextViewText(R.id.widget_dns, name)

        appWidgetManager.updateAppWidget(thisWidget, remoteViews)
    }

    private fun update(host: String){
        val appWidgetManager = AppWidgetManager.getInstance(this)
        val remoteViews = RemoteViews(this.packageName, R.layout.widget_active)
        val thisWidget = ComponentName(this, ActiveWidgetProvider::class.java)

        val t: Tunnel = this.inject().instance()
        remoteViews.setTextViewText(R.id.widget_counter, t.tunnelDropCount.toString())

        remoteViews.setTextViewText(R.id.widget_host, host)

        appWidgetManager.updateAppWidget(thisWidget, remoteViews)
    }

    private fun color(active: Boolean, waiting: Boolean): Int {
        return when {
            waiting -> resources.getColor(R.color.colorLogoWaiting)
            active -> resources.getColor(android.R.color.transparent)
            else -> resources.getColor(R.color.colorLogoInactive)
        }
    }
}

class ConfigWidgetActivity: Activity(){
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


        val preview = findViewById<View>(R.id.widget_preview)

        preview.findViewById<TextView>(R.id.widget_counter).text = "17835"
        preview.findViewById<TextView>(R.id.widget_host).text = "evil-tracker.com"
        preview.findViewById<TextView>(R.id.widget_dns).text = "1.1.1.1"

        var cb = findViewById<CheckBox>(R.id.widget_show_counter)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val tv = preview.findViewById<TextView>(R.id.widget_counter)
            if(isChecked){
                tv.visibility = View.VISIBLE

            }else{
                tv.visibility = View.INVISIBLE
            }
        }

        cb = findViewById(R.id.widget_show_host)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val host = preview.findViewById<TextView>(R.id.widget_host)
            var ll = preview.findViewById<LinearLayout>(R.id.widget_exta_info)
            val infoParams = ll.layoutParams as LinearLayout.LayoutParams
            if(isChecked){
                host.visibility = View.VISIBLE

                infoParams.weight = 1.0f
                infoParams.width = LinearLayout.LayoutParams.WRAP_CONTENT
                ll.layoutParams = infoParams

                ll = findViewById(R.id.widget_preview)
                ll.weightSum = 2.0f
            }else{
                host.visibility = View.INVISIBLE
                if(!findViewById<CheckBox>(R.id.widget_show_dns).isChecked){
                    infoParams.weight = 0f
                    infoParams.width = 0
                    ll.layoutParams = infoParams

                    ll = findViewById(R.id.widget_preview)
                    ll.weightSum = 1.0f
                }
            }
        }

        cb = findViewById(R.id.widget_show_dns)

        cb.setOnCheckedChangeListener { buttonView, isChecked ->
            val dns = preview.findViewById<TextView>(R.id.widget_dns)
            var ll = preview.findViewById<LinearLayout>(R.id.widget_exta_info)
            val infoParams = ll.layoutParams as LinearLayout.LayoutParams
            if(isChecked){
                dns.visibility = View.VISIBLE

                infoParams.weight = 1.0f
                infoParams.width = LinearLayout.LayoutParams.WRAP_CONTENT

                ll.layoutParams = infoParams
                ll = findViewById(R.id.widget_preview)
                ll.weightSum = 2.0f
            }else{
                dns.visibility = View.INVISIBLE
                if(!findViewById<CheckBox>(R.id.widget_show_host).isChecked){
                    infoParams.weight = 0f
                    infoParams.width = 0
                    ll.layoutParams = infoParams

                    ll = findViewById(R.id.widget_preview)
                    ll.weightSum = 1.0f
                }
            }
        }

        val sb = findViewById<SeekBar>(R.id.widget_alpha)
        sb.setOnSeekBarChangeListener(object : OnSeekBarChangeListener {

            override fun onStopTrackingTouch(seekBar: SeekBar) {
            }

            override fun onStartTrackingTouch(seekBar: SeekBar) {
            }

            override fun onProgressChanged(seekBar: SeekBar, progress: Int, fromUser: Boolean) {
                (preview as LinearLayout).background.alpha = progress
            }
        })

        //TODO: change min-width for different configs?

        val btn = findViewById<Button>(R.id.widget_okay)
        btn.setOnClickListener {
            val appWidgetManager = AppWidgetManager.getInstance(this)

            val views = RemoteViews(this.packageName,
                    R.layout.widget_active)

            if(findViewById<CheckBox>(R.id.widget_show_counter).isChecked){
                val t: Tunnel = this.inject().instance()
                views.setTextViewText(R.id.widget_counter, t.tunnelDropCount.toString())
                views.setViewVisibility(R.id.widget_counter,View.VISIBLE)
            }else{
                views.setViewVisibility(R.id.widget_counter,View.GONE)
            }

            if(findViewById<CheckBox>(R.id.widget_show_host).isChecked){
                val t: Tunnel = this.inject().instance()
                val droppedlist = t.tunnelRecentDropped.invoke()
                if(droppedlist.isNotEmpty()){
                            views.setTextViewText(R.id.widget_host,droppedlist.last())
                }
                views.setViewVisibility(R.id.widget_host,View.VISIBLE)
            }else{
                views.setViewVisibility(R.id.widget_spacer,View.GONE)
                views.setViewVisibility(R.id.widget_host,View.GONE)
            }

            if(findViewById<CheckBox>(R.id.widget_show_dns).isChecked){
                val d: Dns = this.inject().instance()
                val i18n: I18n = this.inject().instance()
                val dc = d.choices.invoke().find { it.active }
                val name = when {
                    dc == null -> this.getString(R.string.dns_text_none)
                    dc.servers.isEmpty() -> this.getString(R.string.dns_text_none)
                    dc.id.startsWith("custom") -> printServers(dc.servers)
                    else -> i18n.localisedOrNull("dns_${dc.id}_name") ?: dc.id.capitalize()
                }
                views.setTextViewText(R.id.widget_dns, name)

                views.setViewVisibility(R.id.widget_dns,View.VISIBLE)
            }else{
                views.setViewVisibility(R.id.widget_spacer,View.GONE)
                views.setViewVisibility(R.id.widget_dns,View.GONE)
            }

            views.setInt(R.id.widget_root,"setBackgroundColor", findViewById<SeekBar>(R.id.widget_alpha).progress shl 24 or 0x00262626)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            //appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.notes_list);
            val resultValue = Intent()
            resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            setResult(RESULT_OK, resultValue)
            finish()
        }
    }
}


