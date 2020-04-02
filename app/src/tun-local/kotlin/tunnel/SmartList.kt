package tunnel

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.github.michaelbull.result.getOr
import com.github.michaelbull.result.mapBoth
import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import filter.DefaultSourceProvider
import gs.property.Device
import gs.property.I18n
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import org.blokada.R
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.*
import kotlin.collections.HashSet


private val asyncContext = newSingleThreadContext("smartlist-main") + logCoroutineExceptions()
const val SMARTLIST_REQUEST_CODE = 1105321546 // random 32 bit value
//val smartlistLogfile = File(core.Persistence.global.getPathForSmartList(), "smartlist.log")
val smartlistListfile = File(core.Persistence.global.getPathForSmartList(), "smartlist.hosts")
val smartlistFilter = Filter("smart", FilterSourceDescriptor("file", smartlistListfile.absolutePath))

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

data class SmartListConfig (
        val state: SmartListState = SmartListState.DEACTIVATED,
        val numBatches: Int = 0
)

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
    private var store = FilterStore(lastFetch = 0)


    override fun onReceive(context: Context, intent: Intent) { //TODO split into multiple smaller functions
        val tunnelConfig = get(TunnelConfig::class.java)
        val smartConfig = get(SmartListConfig::class.java)
        when(smartConfig.state) {
            SmartListState.ACTIVE_PHASE1 -> {
                val newHosts = SmartListLogger.load { it.state == RequestState.BLOCKED_NORMAL || it.state == RequestState.BLOCKED_CNAME }
                val smartlistFile = FileOutputStream(smartlistListfile, true).writer()
                newHosts.forEach { host ->
                    v(host)
                    smartlistFile.write(host + '\n')
                }
                smartlistFile.close()
                SmartListLogger.clear()
                set(SmartListConfig::class.java,SmartListConfig(state = SmartListState.ACTIVE_PHASE2))
                entrypoint.onFiltersChanged()

            }
            SmartListState.ACTIVE_PHASE2 -> {
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
                                    || it.lastFetch + tunnelConfig.cacheTTL * 1000 > System.currentTimeMillis()
                                    || tunnelConfig.wifiOnly && !onWifi && !tunnelConfig.firstLoad && it.source.id == "link"
                        },
                        doValidateFilterStoreCache = {
                            it.cache.isNotEmpty()
                                    && (it.lastFetch + tunnelConfig.cacheTTL * 1000 > System.currentTimeMillis()
                                    || tunnelConfig.wifiOnly && !onWifi)
                        }
                )
                filterManager.load()
                val ctx = getActiveContext()!!
                Persistence.filters.load(ctx.ktx("persistence")).mapBoth(
                success = {
                    v("loaded FilterStore from persistence", it.url, it.cache.size)
                    emit(TunnelEvents.FILTERS_CHANGED, it.cache)
                    store = it
                },
                failure = {
                    e("failed loading FilterStore from persistence", it)
                })

                val url = tunnelConfig.filtersUrl
                if (url != null) filterManager.setUrl(url)
                async(asyncContext) {
                    val whitelists = store.cache.filter { it.active && it.whitelist }
                    if(intent.getBooleanExtra("cleanup", false)) {
                        val currentList = Scanner(FileInputStream(smartlistListfile))
                        val currentHosts = HashSet<String>()
                        val cleanedHosts = HashSet<String>()
                        while (currentList.hasNextLine()) {
                            currentHosts.add(currentList.nextLine())
                        }
                        currentList.close()
                        if (filterManager.sync(whitelists.toSet())) {
                            currentHosts.forEach { host ->
                                if (filterManager.blockade.allowed(host)) {
                                    currentHosts.remove(host)
                                }
                            }
                        }

                        store.cache.filter { it.active && !it.whitelist }.forEach {
                            if (filterManager.sync(setOf(it))) {
                                currentHosts.forEach { host ->
                                    if (filterManager.blockade.denied(host)) {
                                        cleanedHosts.add(host)
                                    }
                                }
                            }
                        }


                        val smartlistFile = FileOutputStream(smartlistListfile, false).writer()
                        cleanedHosts.forEach { host ->
                            v(host)
                            smartlistFile.write(host + '\n')
                        }
                        smartlistFile.close()
                        showSnack(R.string.tunnel_config_smartlist_clean_done)
                    }else{
                        val newHosts = HashSet<String>()
                        val loggedHosts = SmartListLogger.load { !it.blocked }

                        store.cache.filter { it.active && !it.whitelist }.forEach {
                            val activeFilters = whitelists.toMutableSet()
                            activeFilters.add(it)
                            activeFilters.add(smartlistFilter.copy(whitelist = true)) // keep existing entries from being added again.
                            if (filterManager.sync(activeFilters)) {
                                loggedHosts.forEach { host ->
                                    if (filterManager.blockade.denied(host) && (!filterManager.blockade.allowed(host))) {
                                        newHosts.add(host)
                                    }
                                }
                            }
                        }

                        val smartlistFile = FileOutputStream(smartlistListfile, true).writer()
                        newHosts.forEach { host ->
                            v(host)
                            smartlistFile.write(host + '\n')
                        }
                        smartlistFile.close()
                        SmartListLogger.clear()
                    }
                    entrypoint.onFiltersChanged()
                }
            }
            else -> {
                showSnack(R.string.tunnel_config_smartlist_clean_inactive)
                w("Smartlist alarm active while Smartlist is deactivated!")
            }
        }

    }
}



class SmartListLogger{

    companion object{
        private const val SMARTLIST_LOG_CATEGORY = "smart-batch"

        fun log(requests: List<ExtendedRequest>){ //TODO use request batches instead
            val config = get(SmartListConfig::class.java)
            if(config.state != SmartListState.DEACTIVATED) {
                Persistence.request.saveBatch(SMARTLIST_LOG_CATEGORY, config.numBatches, requests)
                set(SmartListConfig::class.java, config.copy(numBatches = config.numBatches + 1))
             }
        }

        fun load(filter: (ExtendedRequest) -> Boolean): HashSet<String>{
            val config = get(SmartListConfig::class.java)
            val domains = HashSet<String>()

            for (i in 0..config.numBatches){
                domains.addAll(
                        Persistence.request.load(SMARTLIST_LOG_CATEGORY, i)
                                .getOr { emptyList() }
                                .filter(filter)
                                .map { it.domain }
                )
            }

            return domains
        }

        fun clear(){
            val config = get(SmartListConfig::class.java)
            Persistence.request.clear(SMARTLIST_LOG_CATEGORY,config.numBatches)
            set(SmartListConfig::class.java, config.copy(numBatches = 0))
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
                switched = get(SmartListConfig::class.java).state != SmartListState.DEACTIVATED,
                action2 = Slot.Action(i18n.getString(R.string.tunnel_config_smartlist_reset_btn)) {
                    val cfg = get(SmartListConfig::class.java)
                    if (cfg.state != SmartListState.DEACTIVATED) {
                        smartlistListfile.delete()
                        SmartListLogger.clear()
                        set(SmartListConfig::class.java, SmartListConfig(state = SmartListState.ACTIVE_PHASE1))
                        showSnack(R.string.tunnel_config_smartlist_reset_done)
                        entrypoint.onFiltersChanged()
                    }
                },
                action3 = Slot.Action(i18n.getString(R.string.tunnel_config_smartlist_clean_btn)) {
                    if(get(SmartListConfig::class.java).state != SmartListState.ACTIVE_PHASE2){
                        showSnack(R.string.tunnel_config_smartlist_clean_none)
                    }else {
                        val intent = Intent(ctx, OnGenerateSmartListReceiver::class.java)
                        intent.putExtra("cleanup", true)
                        ctx.sendBroadcast(intent)
                    }
                }
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
                set(SmartListConfig::class.java, SmartListConfig(state = newState))
                entrypoint.onFiltersChanged()
            }
        }
    }

}
fun setSmartListPersistenceSource() {
    Register.sourceFor(SmartListConfig::class.java, default = SmartListConfig(SmartListState.DEACTIVATED),
            source = PaperSource("smartListConfig"))
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
