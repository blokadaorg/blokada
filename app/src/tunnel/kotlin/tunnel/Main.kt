package tunnel

import android.net.VpnService
import com.github.michaelbull.result.onFailure
import core.*
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import java.io.FileDescriptor
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.util.*

object Events {
    val RULESET_BUILDING = "RULESET_BUILDING".newEventOf<Unit>()
    val RULESET_BUILT = "RULESET_BUILT".newEventOf<Pair<Int, Int>>()
    val FILTERS_CHANGING = "FILTERS_CHANGING".newEvent()
    val FILTERS_CHANGED = "FILTERS_CHANGED".newEventOf<Collection<Filter>>()
    val REQUEST = "REQUEST".newEventOf<Request>()
    val TUNNEL_POWER_SAVING = "TUNNEL_POWER_SAVING".newEvent()
    val MEMORY_CAPACITY = "MEMORY_CAPACITY".newEventOf<Int>()
}

class Main(
        private val onVpnClose: (Kontext) -> Unit,
        private val onVpnConfigure: (Kontext, VpnService.Builder) -> Unit,
        private val onRequest: Callback<Request>,
        private val doResolveFilterSource: (Filter) -> IFilterSource,
        private val doProcessFetchedFilters: (Set<Filter>) -> Set<Filter>
) {

    private val forwarder = Forwarder()
    private val loopback = LinkedList<Triple<ByteArray, Int, Int>>()
    private val blockade = Blockade()
    private var currentServers = emptyList<InetSocketAddress>()
    private var filters = FilterManager(blockade = blockade, doResolveFilterSource =
    doResolveFilterSource, doProcessFetchedFilters = doProcessFetchedFilters)
    private var socketCreator = {
        "socketCreator".ktx().w("using not protected socket")
        DatagramSocket()
    }
    private var config = TunnelConfig()
    private var blockaConfig = BlockaConfig()
    private var proxy = createProxy()
    private var tunnel = createTunnel()
    private var connector = ServiceConnector(
            onClose = onVpnClose,
            onConfigure = { ktx, tunnel -> 0L }
    )
    private var currentUrl: String = ""

    private var tunnelThread: Thread? = null
    private var fd: FileDescriptor? = null
    private var binder: ServiceBinder? = null
    private var enabled: Boolean = false

    private val CTRL = newSingleThreadContext("tunnel-ctrl")
    private var threadCounter = 0
    private var usePausedConfigurator = false

    private fun createProxy() = if (blockaConfig.blockaVpn) null
            else DnsProxy(currentServers, blockade, forwarder, loopback, doCreateSocket = socketCreator)

    private fun createTunnel() = if (blockaConfig.blockaVpn) BlockaTunnel(currentServers, config,
            blockaConfig, socketCreator, blockade)
            else DnsTunnel(proxy!!, config, forwarder, loopback)

    private fun createConfigurator() = when {
        usePausedConfigurator -> PausedVpnConfigurator(currentServers, filters)
        blockaConfig.blockaVpn -> BlockaVpnConfigurator(currentServers, filters, blockaConfig)
        else -> DnsVpnConfigurator(currentServers, filters)
    }

    fun setup(ktx: AndroidKontext, servers: List<InetSocketAddress>, config: BlockaConfig? = null, start: Boolean = false) = async(CTRL) {
        ktx.v("setup tunnel, start = $start, enabled = $enabled", servers, config ?: "null")
        enabled = start or enabled
        when {
            servers.isEmpty() -> {
                ktx.v("empty dns servers, will disable tunnel")
                currentServers = emptyList()
                maybeStopVpn(ktx)
                maybeStopTunnelThread(ktx)
                if (start) enabled = true
            }
            isVpnOn() && currentServers == servers && (config == null ||
                    blockaConfig.blockaVpn == config.blockaVpn
                    && blockaConfig.gatewayId == config.gatewayId
                    && blockaConfig.adblocking == config.adblocking) -> {
                ktx.v("no changes in configuration, ignoring")
            }
            else -> {
                currentServers = servers
                config?.run { blockaConfig = this }
                socketCreator = {
                    val socket = DatagramSocket()
                    val protected = binder?.service?.protect(socket) ?: false
                    if (!protected) "socketCreator".ktx().e("could not protect")
                    socket
                }
                proxy = createProxy()
                tunnel = createTunnel()
                val configurator = createConfigurator()

                connector = ServiceConnector(onVpnClose, onConfigure = { ktx, vpn ->
                    configurator.configure(ktx, vpn)
                    onVpnConfigure(ktx, vpn)
                    5000L
                })

                ktx.v("will sync filters")
                if (filters.sync(ktx)) {
                    filters.save(ktx)

                    ktx.v("will restart vpn and tunnel")
                    maybeStopTunnelThread(ktx)
                    maybeStopVpn(ktx)
                    ktx.v("done stopping vpn and tunnel")

                    if (enabled) {
                        ktx.v("will start vpn")
                        startVpn(ktx)
                        startTunnelThread(ktx)
                    }
                }
            }
        }
        Unit
    }

    fun reloadConfig(ktx: AndroidKontext, onWifi: Boolean) = async(CTRL) {
        ktx.v("reloading config")
        createComponents(ktx, onWifi)
        filters.setUrl(ktx, currentUrl)
        if (filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun setUrl(ktx: AndroidKontext, url: String, onWifi: Boolean) = async(CTRL) {
        if (url != currentUrl) {
            currentUrl = url

            val cfg = Persistence.config.load(ktx)
            ktx.v("setting url, firstLoad: ${cfg.firstLoad}", url)
            createComponents(ktx, onWifi)
            filters.setUrl(ktx, url)
            if (filters.sync(ktx)) {
                ktx.v("first fetch successful, unsetting firstLoad flag")
                Persistence.config.save(cfg.copy(firstLoad = false))
            }
            filters.save(ktx)
            restartTunnelThread(ktx)
        } else ktx.w("ignoring setUrl, same url already set")
    }


    fun stop(ktx: AndroidKontext) = async(CTRL) {
        ktx.v("stopping tunnel")
        maybeStopTunnelThread(ktx)
        maybeStopVpn(ktx)
        currentServers = emptyList()
        enabled = false
    }

    fun load(ktx: AndroidKontext) = async(CTRL) {
        filters.load(ktx)
        restartTunnelThread(ktx)
    }

    fun sync(ktx: AndroidKontext, restartVpn: Boolean = false) = async(CTRL) {
        ktx.v("syncing on request")
        if (filters.sync(ktx)) {
            filters.save(ktx)
            if (restartVpn) restartVpn(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun putFilter(ktx: AndroidKontext, filter: Filter, sync: Boolean = true) = async(CTRL) {
        ktx.v("putting filter", filter.id)
        filters.put(ktx, filter)
        if (sync) sync(ktx, restartVpn = filter.source.id == "app")
    }

    fun putFilters(ktx: AndroidKontext, newFilters: Collection<Filter>) = async(CTRL) {
        ktx.v("batch putting filters", newFilters.size)
        newFilters.forEach { filters.put(ktx, it) }
        if (filters.sync(ktx)) {
            filters.save(ktx)
            if (newFilters.any { it.source.id == "app" }) restartVpn(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun removeFilter(ktx: AndroidKontext, filter: Filter) = async(CTRL) {
        filters.remove(ktx, filter)
        if (filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun invalidateFilters(ktx: AndroidKontext) = async(CTRL) {
        ktx.v("invalidating filters")
        filters.invalidateCache(ktx)
        if(filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun deleteAllFilters(ktx: AndroidKontext) = async(CTRL) {
        filters.removeAll(ktx)
        if (filters.sync(ktx)) {
            restartTunnelThread(ktx)
        }
    }

    fun protect(socket: Socket) {
        val protected = binder?.service?.protect(socket) ?: false
        if (!protected && isVpnOn()) "socketCreator".ktx().e("could not protect", socket)
    }

    private fun createComponents(ktx: AndroidKontext, onWifi: Boolean) {
        config = Persistence.config.load(ktx)
        blockaConfig = Persistence.blocka.load(ktx)
        ktx.v("create components, onWifi: $onWifi, firstLoad: ${config.firstLoad}", config)
        proxy = createProxy()
        tunnel = createTunnel()
        filters = FilterManager(
                blockade = blockade,
                doResolveFilterSource = doResolveFilterSource,
                doProcessFetchedFilters = doProcessFetchedFilters,
                doValidateRulesetCache = { it ->
                    it.source.id in listOf("app")
                            || it.lastFetch + config.cacheTTL * 1000 > System.currentTimeMillis()
                            || config.wifiOnly && !onWifi && !config.firstLoad && it.source.id == "link"
                },
                doValidateFilterStoreCache = { it ->
                    it.cache.isNotEmpty()
                            && (it.lastFetch + config.cacheTTL * 1000 > System.currentTimeMillis()
                            || config.wifiOnly && !onWifi)
                }
        )
        filters.load(ktx)
    }

    private suspend fun startVpn(ktx: AndroidKontext) {
        Result.of {
            val binding = connector.bind(ktx)
            runBlocking { binding.join() }
            binder = binding.getCompleted()
            fd = binder!!.service.turnOn(ktx)
            ktx.on(Events.REQUEST, onRequest)
            ktx.v("vpn started")
        }.onFailure { ex ->
            ktx.e("failed starting vpn", ex)
            onVpnClose(ktx)
        }
    }

    private fun startTunnelThread(ktx: AndroidKontext) {
        proxy = createProxy()
        tunnel = createTunnel()
        val f = fd
        if (f != null) {
            tunnelThread = Thread({ tunnel.runWithRetry(ktx, f) }, "tunnel-${threadCounter++}")
            tunnelThread?.start()
            ktx.v("tunnel thread started", tunnelThread!!)
        } else ktx.w("attempting to start tunnel thread with no fd")
    }

    private fun stopTunnelThread(ktx: Kontext) {
        ktx.v("stopping tunnel thread", tunnelThread!!)
        tunnel.stop(ktx)
        Result.of { tunnelThread?.interrupt() }.onFailure { ex ->
            ktx.w("could not interrupt tunnel thread", ex)
        }
        Result.of { tunnelThread?.join(5000); true }.onFailure { ex ->
            ktx.w("could not join tunnel thread", ex)
        }
        tunnelThread = null
        ktx.v("tunnel thread stopped")
    }

    private fun stopVpn(ktx: AndroidKontext) {
        ktx.cancel(Events.REQUEST, onRequest)
        binder?.service?.turnOff(ktx)
        connector.unbind(ktx)//.mapError { ex -> ktx.w("failed unbinding connector", ex) }
        binder = null
        fd = null
        ktx.v("vpn stopped")
    }

    private fun restartTunnelThread(ktx: AndroidKontext) {
        if (tunnelThread != null) {
            stopTunnelThread(ktx)
            startTunnelThread(ktx)
        }
    }

    private suspend fun restartVpn(ktx: AndroidKontext) {
        if (isVpnOn()) {
            stopVpn(ktx)
            startVpn(ktx)
        }
    }

    private fun maybeStartTunnelThread(ktx: AndroidKontext) = if (tunnelThread == null) {
        startTunnelThread(ktx)
    } else Unit

    private fun maybeStopTunnelThread(ktx: Kontext) = if (tunnelThread != null) {
        stopTunnelThread(ktx); true
    } else false

    private suspend fun maybeStartVpn(ktx: AndroidKontext) = if (!isVpnOn()) startVpn(ktx) else Unit

    private fun maybeStopVpn(ktx: AndroidKontext) = if (isVpnOn()) {
        stopVpn(ktx); true
    } else false

    private fun isVpnOn() = binder != null
}
