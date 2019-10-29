package tunnel

import blocka.BlockaVpnState
import blocka.CurrentAccount
import blocka.CurrentLease
import com.github.salomonbrys.kodein.instance
import core.*
import core.Register.set
import filter.DefaultSourceProvider
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import java.net.InetSocketAddress
import java.net.Socket

object TunnelEvents {
    val RULESET_BUILDING = "RULESET_BUILDING".newEventOf<Unit>()
    val RULESET_BUILT = "RULESET_BUILT".newEventOf<Pair<Int, Int>>()
    val FILTERS_CHANGING = "FILTERS_CHANGING".newEvent()
    val FILTERS_CHANGED = "FILTERS_CHANGED".newEventOf<Collection<Filter>>()
    val REQUEST = "REQUEST".newEventOf<Request>()
    val TUNNEL_POWER_SAVING = "TUNNEL_POWER_SAVING".newEvent()
    val MEMORY_CAPACITY = "MEMORY_CAPACITY".newEventOf<Int>()
    val TUNNEL_RESTART = "TUNNEL_RESTART".newEventOf<Int>()
}

private val context = newSingleThreadContext("tunnel-main") + logCoroutineExceptions()

val tunnelMain = runBlocking { async(context) { TunnelMain() }.await() }

class TunnelMain {


    private val ctx by lazy { getActiveContext()!! }
    private val di by lazy { ctx.ktx("tunnel-main").di() }
    private val filtersState by lazy { di.instance<Filters>() }

    private val sourceProvider by lazy {
        DefaultSourceProvider(ctx, di.instance(), filtersState, di.instance())
    }

    private lateinit var blockade: Blockade
    private lateinit var tunnelManager: TunnelManager
    private lateinit var filterManager: FilterManager

    private fun createBlockade(config: TunnelConfig) = when {
        config.wildcards -> WildcardBlockade()
        else -> BasicBlockade()
    }

    private fun createTunnelManager() = TunnelManagerFactory(ctx,
            tunnelState = di.instance(),
            blockade = blockade,
            filterManager = { filterManager },
            tunnelConfig = { tunnelConfig }
    ).create()

    private fun createFilterManager(config: TunnelConfig, onWifi: Boolean) = FilterManager(
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

    private var tunnelConfig = get(TunnelConfig::class.java)
    private var currentTunnel = CurrentTunnel()
    private var onWifi = false
    private var needRecreateManagers = true

    fun setFiltersUrl(url: String) = async(context) {
        v(">> setting filters url", url)
        when {
            url == tunnelConfig.filtersUrl -> w("same url already set, ignoring")
            else -> {
                tunnelConfig = tunnelConfig.copy(filtersUrl = url)
                needRecreateManagers = true
            }
        }
    }

    fun setNetworkConfiguration(dnsServers: List<InetSocketAddress>, onWifi: Boolean) = async(context) {
        // TODO: potentially it would be better to fetch network config on sync instead of being fed
        v(">> setting network configuration. onWifi: $onWifi", dnsServers)

        if (dnsServers == currentTunnel.dnsServers && this@TunnelMain.onWifi == onWifi) {
            w("no change in network configuration, ignoring")
        } else {
            if (this@TunnelMain.onWifi != onWifi) {
                v("onWifi changed", onWifi)
                this@TunnelMain.onWifi = onWifi
                needRecreateManagers = true
            }

            currentTunnel = currentTunnel.copy(dnsServers = dnsServers)
        }
    }

    fun setAdblocking(adblocking: Boolean) = async(context) {
        v(">> setting adblocking", adblocking)
        setTunnelConfiguration(tunnelConfig.copy(adblocking = adblocking))
    }

    fun setTunnelConfiguration(tunnelConfig: TunnelConfig) = async(context) {
        v(">> setting tunnel configuration", tunnelConfig)

        if (this@TunnelMain.tunnelConfig == tunnelConfig) {
            w("no change in tunnel configuration, ignoring")
        } else {
            // TODO: set network configuration if fallback was switched around. any more?
            this@TunnelMain.tunnelConfig = tunnelConfig
            set(TunnelConfig::class.java, tunnelConfig)
            needRecreateManagers = true
        }
    }

    fun sync() = async(context) {
        v(">> syncing tunnel overall state")
        if (needRecreateManagers) {
            if (::tunnelManager.isInitialized) {
                v("recreating FilterManager (stopping tunnel first)")
                keepAliveAgent.fireJob(ctx) // To prevent death in the meantime
                tunnelManager.stop()
            }
            blockade = createBlockade(tunnelConfig)
            tunnelManager = createTunnelManager()
            filterManager = createFilterManager(tunnelConfig, onWifi)
            filterManager.load()
            needRecreateManagers = false
        }

        v("syncing filters")
        val url = tunnelConfig.filtersUrl
        if (url != null) filterManager.setUrl(url)
        if (filterManager.hasUrl()) {
            if (filterManager.sync()) {
                if (tunnelConfig.firstLoad) {
                    v("first fetch successful, unsetting firstLoad flag")
                    tunnelConfig = tunnelConfig.copy(firstLoad = false)
                    set(TunnelConfig::class.java, tunnelConfig)
                }
            }
            filterManager.save()
        } else w("no filters url set, will skip syncing filters")

        v("actually setting vpn tunnel")
        currentTunnel = currentTunnel.copy(
                blockaVpn = get(BlockaVpnState::class.java).enabled,
                userBoringtunPrivateKey = get(CurrentAccount::class.java).privateKey,
                lease = get(CurrentLease::class.java),
                adblocking = tunnelConfig.adblocking
        )

        tunnelManager.setState(currentTunnel)
        if (tunnelConfig.tunnelEnabled) {
            tunnelManager.sync()
        } else {
            v("tunnel not enabled, stopping")
            tunnelManager.stop()
        }
        v("done syncing")
    }

    fun findFilterBySource(source: String) = async(context) {
        filterManager.findBySource(source)
    }

    fun putFilter(filter: Filter) = async(context) {
        v("putting filter", filter.id)
        filterManager.put(filter)
    }

    fun putFilters(newFilters: Collection<Filter>) = async(context) {
        v("batch putting filters", newFilters.size)
        newFilters.forEach { filterManager.put(it) }
    }

    fun removeFilter(filter: Filter) = async(context) {
        filterManager.remove(filter)
    }

    fun invalidateFilters() = async(context) {
        v("invalidating filters")
        filterManager.invalidateCache()
    }

    fun deleteAllFilters() = async(context) {
        filterManager.removeAll()
    }

    fun protect(socket: Socket) = tunnelManager.protect(socket)
}
