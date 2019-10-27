package tunnel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import kotlinx.coroutines.experimental.async
import com.github.salomonbrys.kodein.instance
import core.*
import filter.DefaultSourceProvider
import gs.property.Device
import gs.property.I18n
import kotlinx.coroutines.experimental.newSingleThreadContext
import org.blokada.R
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.PrintWriter
import java.util.*
import kotlin.collections.HashSet


private val asyncContext = newSingleThreadContext("blocka-vpn-main") + logCoroutineExceptions()
val SMARTLIST_REQUEST_CODE = 1105321546 // random 32 bit value
class OnGenerateSmartListReceiver : BroadcastReceiver() {

    private val blockade = Blockade()

    private val ctx by lazy { getActiveContext()!! }
    private val di by lazy { ctx.ktx("tunnel-main").di() }
    private val filtersState by lazy { di.instance<Filters>() }

    private val sourceProvider by lazy {
        DefaultSourceProvider(ctx, di.instance(), filtersState, di.instance())
    }
    private val config = get(TunnelConfig::class.java)
    private val device by lazy { di.instance<Device>() }
    private val onWifi = device.onWifi()


    override fun onReceive(context: Context, intent: Intent) {
        val data = Scanner(FileInputStream(File(core.Persistence.global.loadPath(), "allowed.log")))
        val filterManager = FilterManager(
            blockade = blockade,
            doResolveFilterSource = {
                sourceProvider.from(it.source.id, it.source.source)
            },
            doProcessFetchedFilters = {
                filtersState.apps.refresh(blocking = true)
                it.map {
                    when {
                        it.source.id != "app" -> it
                        filtersState.apps().firstOrNull { a -> a.appId == it.source.source } == null -> {
                            it.copy(hidden = true, active = false)
                        }
                        else -> it
                    }
                }.toSet()
            },
            doValidateRulesetCache = {
                it.source.id in listOf("app")
                        || it.lastFetch + config.cacheTTL * 1000 > System.currentTimeMillis()
                        || config.wifiOnly && !onWifi && !config.firstLoad && it.source.id == "link"
            },
            doValidateFilterStoreCache = {
                it.cache.isNotEmpty()
                        && (it.lastFetch + config.cacheTTL * 1000 > System.currentTimeMillis()
                        || config.wifiOnly && !onWifi)
            }
        )
        filterManager.load()
        val url = config.filtersUrl
        if (url != null) filterManager.setUrl(url)
        val newHosts = HashSet<String>()
        async(asyncContext) {
            if (filterManager.sync(true)) {
                while (data.hasNextLine()) {
                    val host = data.nextLine()
                    if (filterManager.blockade.denied(host) && (!filterManager.blockade.allowed(host))) {
                        newHosts.add(host)
                    }
                }
            }
            val smartlistFile = FileOutputStream(File(core.Persistence.global.loadPath() + "/smartlist.txt"), true).writer()
            newHosts.forEach { host ->
                v(host)
                smartlistFile.write(host + '\n')
            }
            smartlistFile.close()
            data.close()
            SmartListLogger.clear()
            entrypoint.onFiltersChanged()
        }

    }
}



class SmartListLogWriter {

    private var file: PrintWriter? = try {
        val path = File(core.Persistence.global.loadPath(), "allowed.log")
        val writer = PrintWriter(FileOutputStream(path, true), true)
        writer
    } catch (ex: Exception) {
        null
    }

    private var lastLine = ""

    @Synchronized
    internal fun writer(line: String) {
        if(line != lastLine) {
            lastLine = line
            file?.println(line)
        }
    }

    @Synchronized
    internal fun clear() {
        val path = File(core.Persistence.global.loadPath(), "allowed.log")
        file?.close()
        file = PrintWriter(FileOutputStream(path, false), true)
    }
}


class SmartListLogger{

    companion object{
        private val smartListLogWriter: SmartListLogWriter = SmartListLogWriter()

        @Synchronized
        fun log(request: Request){
            if (!request.blocked && get(TunnelConfig::class.java).smartList) {
                smartListLogWriter.writer(request.domain)
            }
        }

        @Synchronized
        fun clear(){
            smartListLogWriter.clear()
        }
    }
}


class SmartListVB(
        private val ktx: AndroidKontext,
        private val ctx: Context = ktx.ctx,
        private val i18n: I18n = ktx.di().instance(),
        onTap: (SlotView) -> Unit
) : SlotVB(onTap) {

    override fun attach(view: SlotView) {
        view.enableAlternativeBackground()
        view.type = Slot.Type.INFO
        view.content = Slot.Content(
                label = i18n.getString(R.string.tunnel_config_smartlist_title),
                icon = ctx.getDrawable(org.blokada.R.drawable.ic_server),
                description = i18n.getString(R.string.tunnel_config_smartlist_description),
                switched = get(TunnelConfig::class.java).smartList
        )
        view.onSwitch = {
            setSmartlistAlarmActive(ctx, it)
            val new = get(TunnelConfig::class.java).copy(smartList= it)
            entrypoint.onChangeTunnelConfig(new)
        }
    }

}

fun setSmartlistAlarmActive(ctx: Context, active: Boolean){
    val alarmManager = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager?
    val intent = Intent(ctx, OnGenerateSmartListReceiver::class.java).let { intent ->
        PendingIntent.getBroadcast(ctx, SMARTLIST_REQUEST_CODE, intent, 0)
    }
    if(active) {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.HOUR, 8)
        calendar.set(Calendar.HOUR, 4)
        calendar.set(Calendar.AM_PM, Calendar.PM)
        calendar.set(Calendar.MINUTE, 0)
        alarmManager!!.setRepeating(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, 24 * 60 * 60 * 1000, intent)
    }else{
        alarmManager!!.cancel(intent)
    }
}