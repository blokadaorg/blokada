package tunnel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.github.salomonbrys.kodein.instance
import core.*
import filter.DefaultSourceProvider
import gs.property.Device
import gs.property.I18n
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import org.blokada.R
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.PrintWriter
import java.util.*
import kotlin.collections.HashSet


private val asyncContext = newSingleThreadContext("smartlist-main") + logCoroutineExceptions()
const val SMARTLIST_REQUEST_CODE = 1105321546 // random 32 bit value
val smartlistLogfile = File(core.Persistence.global.loadPath(), "smartlist.log")
val smartlistListfile = File(core.Persistence.global.loadPath(), "smartlist.hosts")

/*
       DEACTIVATED
++---does smart list exist ? PHASE2 : PHASE1
||     ||
||     \/
||   PHASE1
||     log blocked request
||     wait for 4 AM
||     copy log into new smart list
||     delete old log
||     switch to PHASE2
||     ||
||     \/
++-->PHASE2
       delete old log
       load smart list
       log allowed request
       wait for 4 AM
       load all selected lists
       check all logged requests
       add new entries
       load new smart list
       repeat PHASE2
*/

enum class SmartListState {
    DEACTIVATED, ACTIVE_PHASE1, ACTIVE_PHASE2
}

//Triggered every night at 4AM
class OnGenerateSmartListReceiver : BroadcastReceiver() {

    private val blockade = BasicBlockade()

    private val ctx by lazy { getActiveContext()!! }
    private val di by lazy { ctx.ktx("tunnel-main").di() }
    private val filtersState by lazy { di.instance<Filters>() }

    private val sourceProvider by lazy {
        DefaultSourceProvider(ctx, di.instance(), filtersState, di.instance())
    }
    private val device by lazy { di.instance<Device>() }
    private val onWifi = device.onWifi()


    override fun onReceive(context: Context, intent: Intent) {
        val config = get(TunnelConfig::class.java)
        when(config.smartList) {
            SmartListState.ACTIVE_PHASE1 -> {
                val data = Scanner(FileInputStream(smartlistLogfile))
                val newHosts = HashSet<String>()
                while (data.hasNextLine()) {
                    val host = data.nextLine()
                    newHosts.add(host)
                }
                val smartlistFile = FileOutputStream(smartlistListfile, true).writer()
                newHosts.forEach { host ->
                    v(host)
                    smartlistFile.write(host + '\n')
                }
                smartlistFile.close()
                data.close()
                SmartListLogger.clear()
                val new = get(TunnelConfig::class.java).copy(smartList= SmartListState.ACTIVE_PHASE2)
                entrypoint.onChangeTunnelConfig(new)

            }
            SmartListState.ACTIVE_PHASE2 -> {
                val data = Scanner(FileInputStream(smartlistLogfile))
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
                async(asyncContext) {
                    val newHosts = HashSet<String>()
                    if (filterManager.sync(true)) {
                        while (data.hasNextLine()) {
                            val host = data.nextLine()
                            if (filterManager.blockade.denied(host) && (!filterManager.blockade.allowed(host))) {
                                newHosts.add(host)
                            }
                        }
                    }
                    val smartlistFile = FileOutputStream(smartlistListfile, true).writer()
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
            else -> v("Smartlist alarm active while Smartlist is deactivated!")
        }

    }
}



class SmartListLogWriter {

    private var file: PrintWriter? = try {
        val writer = PrintWriter(FileOutputStream(smartlistLogfile, true), true)
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
        file?.close()
        file = PrintWriter(FileOutputStream(smartlistLogfile, false), true)
    }
}


class SmartListLogger{

    companion object{
        private val smartListLogWriter: SmartListLogWriter = SmartListLogWriter()

        @Synchronized
        fun log(request: Request){
            val state = get(TunnelConfig::class.java).smartList
            if (!request.blocked && state == SmartListState.ACTIVE_PHASE2) {
                smartListLogWriter.writer(request.domain)
            }
            if (request.blocked && state == SmartListState.ACTIVE_PHASE1) {
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
                icon = ctx.getDrawable(R.drawable.ic_playlist_minus),
                description = i18n.getString(R.string.tunnel_config_smartlist_description),
                switched = get(TunnelConfig::class.java).smartList != SmartListState.DEACTIVATED
        )
        view.onSwitch = {
            val cfg = get(TunnelConfig::class.java)
            if (it && cfg.wildcards) {
                view.content = view.content!!.copy(switched = false)
                showSnack(R.string.tunnel_config_disable_wildcard)
            } else {
                setSmartlistAlarmActive(ctx, it)
                val newState = if (it) {
                    if (smartlistListfile.exists() && smartlistListfile.length() > 0) {
                        SmartListState.ACTIVE_PHASE2
                    } else {
                        SmartListState.ACTIVE_PHASE1
                    }
                } else {
                    SmartListState.DEACTIVATED
                }
                val new = cfg.copy(smartList = newState)
                entrypoint.onChangeTunnelConfig(new)
            }
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
        calendar.add(Calendar.HOUR, 20)
        calendar.set(Calendar.HOUR, 4)
        calendar.set(Calendar.AM_PM, Calendar.AM)
        calendar.set(Calendar.MINUTE, 0)
        alarmManager!!.setRepeating(AlarmManager.RTC_WAKEUP, calendar.timeInMillis,24 * 60 * 60 * 1000, intent)
    }else{
        alarmManager!!.cancel(intent)
    }
}
