package tunnel

import android.app.PendingIntent
import android.content.Intent
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
import org.blokada.R
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.util.*

object TunnelEvents {
    val RULESET_BUILDING = "RULESET_BUILDING".newEventOf<Unit>()
    val RULESET_BUILT = "RULESET_BUILT".newEventOf<Pair<Int, Int>>()
    val FILTERS_CHANGING = "FILTERS_CHANGING".newEvent()
    val FILTERS_CHANGED = "FILTERS_CHANGED".newEventOf<Collection<Filter>>()
    val REQUEST = "REQUEST".newEventOf<Request>()
    val TUNNEL_POWER_SAVING = "TUNNEL_POWER_SAVING".newEvent()
    val MEMORY_CAPACITY = "MEMORY_CAPACITY".newEventOf<Int>()
    val TUNNEL_RESTART = "TUNNEL_RESTART".newEvent()
}

private val context = newSingleThreadContext("tunnel-main") + logCoroutineExceptions()

val tunnelMain = runBlocking { async(context) { TunnelMain() }.await() }

class TunnelMain {

    private val forwarder = Forwarder()
    private val loopback = LinkedList<Triple<ByteArray, Int, Int>>()
    private val blockade = Blockade()

    private val ctx by lazy { getActiveContext()!! }
    private val di by lazy { ctx.ktx("tunnel-main").di() }
    private val filtersState by lazy { di.instance<Filters>() }
    private val tunnelState by lazy { di.instance<core.Tunnel>() }

    private val sourceProvider by lazy {
        DefaultSourceProvider(ctx, di.instance(), filtersState, di.instance())
    }

    private val tunnelManager = TunnelManager(
            onVpnClose = { rejected ->
                tunnelState.tunnelPermission.refresh(blocking = true)
                if (rejected) {
                    tunnelState.enabled %= false
                    tunnelState.active %= false
                }
                else {
                    tunnelState.restart %= true
                    tunnelState.active %= false
                }
            },
            onVpnConfigure = { vpn ->
                vpn.setSession(ctx.getString(R.string.branding_app_name))
                        .setConfigureIntent(PendingIntent.getActivity(ctx, 1,
                                Intent(ctx, PanelActivity::class.java),
                                PendingIntent.FLAG_CANCEL_CURRENT))
            },
            createTunnel = this::createTunnel,
            createConfigurator = this::createConfigurator
    )

    private lateinit var filterManager: FilterManager

    private fun createConfigurator(state: CurrentTunnel, binder: ServiceBinder) = when {
        //usePausedConfigurator -> PausedVpnConfigurator(currentServers, filters)
        state.blockaVpn -> {
            BlockaVpnConfigurator(state.dnsServers, filterManager, state.adblocking, state.lease!!,
                    ctx.packageName)
        }
        !state.adblocking -> SimpleVpnConfigurator(state.dnsServers, filterManager)
        else -> DnsVpnConfigurator(state.dnsServers, filterManager, ctx.packageName)
    }

    private fun createTunnel(state: CurrentTunnel, socketCreator: () -> DatagramSocket) = when {
        state.blockaVpn -> {
            BlockaTunnel(state.dnsServers, tunnelConfig.powersave, state.adblocking, state.lease!!,
                    state.userBoringtunPrivateKey!!, socketCreator, blockade)
        }
        !state.adblocking -> null
        else -> {
            val proxy = createProxy(state, socketCreator)
            DnsTunnel(proxy!!, tunnelConfig.powersave, forwarder, loopback)
        }
    }

    private fun createProxy(state: CurrentTunnel, socketCreator: () -> DatagramSocket) = when {
        state.blockaVpn -> null // in VPN mode we don't use proxy class
        else -> DnsProxy(state.dnsServers, blockade, forwarder, loopback, doCreateSocket = socketCreator)
    }

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
    private var needRecreateFilterManager = true

    fun setFiltersUrl(url: String) = async(context) {
        v(">> setting filters url", url)
        when {
            url == tunnelConfig.filtersUrl -> w("same url already set, ignoring")
            else -> {
                tunnelConfig = tunnelConfig.copy(filtersUrl = url)
                needRecreateFilterManager = true
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
                needRecreateFilterManager = true
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
            needRecreateFilterManager = true
        }
    }

    fun sync() = async(context) {
        v(">> syncing tunnel overall state")
        if (needRecreateFilterManager) {
            v("recreating FilterManager (stopping tunnel first)")
            tunnelManager.stop()
            filterManager = createFilterManager(tunnelConfig, onWifi)
            filterManager.load()
            needRecreateFilterManager = false
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
