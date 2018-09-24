package tunnel

import android.net.VpnService
import com.github.michaelbull.result.mapError
import com.github.michaelbull.result.onFailure
import core.*
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import java.io.FileDescriptor
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.*

object Events {
    val RULESET_BUILDING = "RULESET_BUILDING".newEventOf<Unit>()
    val RULESET_BUILT = "RULESET_BUILT".newEventOf<Pair<Int, Int>>()
    val FILTERS_CHANGING = "FILTERS_CHANGING".newEvent()
    val FILTERS_CHANGED = "FILTERS_CHANGED".newEventOf<Collection<Filter>>()
    val BLOCKED = "BLOCKED".newEventOf<String>()
    val TUNNEL_POWER_SAVING = "TUNNEL_POWER_SAVING".newEvent()
    val MEMORY_CAPACITY = "MEMORY_CAPACITY".newEventOf<Int>()
}

class Main(
        private val onVpnClose: (Kontext) -> Unit,
        private val onVpnConfigure: (Kontext, VpnService.Builder) -> Unit,
        private val onBlocked: Callback<String>,
        private val doResolveFilterSource: (Filter) -> IFilterSource,
        private val doProcessFetchedFilters: (Set<Filter>) -> Set<Filter>
) {

    private val forwarder = Forwarder()
    private val loopback = LinkedList<ByteArray>()
    private val blockade = Blockade()
    private var filters = FilterManager(blockade = blockade, doResolveFilterSource =
    doResolveFilterSource, doProcessFetchedFilters = doProcessFetchedFilters)
    private var proxy = Proxy(emptyList(), blockade, forwarder, loopback)
    private var tunnel = Tunnel(proxy, forwarder, loopback)
    private var connector = ServiceConnector(
            onClose = onVpnClose,
            onConfigure = { ktx, tunnel -> 0L }
    )

    private var tunnelThread: Thread? = null
    private var fd: FileDescriptor? = null
    private var binder: ServiceBinder? = null

    private val CTRL = newSingleThreadContext("tunnel-ctrl")
    private var threadCounter = 0
    private var usePausedConfigurator = false

    fun setup(ktx: AndroidKontext, servers: List<InetAddress>, start: Boolean = false) = async(CTRL) {
        ktx.v("setup tunnel", servers)
        if (servers.isEmpty()) {
            ktx.v("empty dns servers, will disable tunnel")
            maybeStopVpn(ktx)
            maybeStopTunnelThread(ktx)
        } else {
            val socketCreator = {
                val socket = DatagramSocket()
                binder?.service?.protect(socket)
                socket
            }
            proxy = Proxy(servers, blockade, forwarder, loopback, doCreateSocket = socketCreator)
            tunnel = Tunnel(proxy, forwarder, loopback)

            val configurator = if (usePausedConfigurator) PausedVpnConfigurator(servers, filters)
            else VpnConfigurator(servers, filters)

            connector = ServiceConnector(onVpnClose, onConfigure = { ktx, vpn ->
                configurator.configure(ktx, vpn)
                onVpnConfigure(ktx, vpn)
                0L
            })

            if (filters.sync(ktx)) {
                filters.save(ktx)

                restartVpn(ktx)
                restartTunnelThread(ktx)

                if (start) {
                    maybeStartVpn(ktx)
                    maybeStartTunnelThread(ktx)
                }
            }
            Unit
        }
    }

    fun reloadConfig(ktx: AndroidKontext, onWifi: Boolean) = async(CTRL) {
        val cfg = Persistence.config.load(ktx)
        ktx.v("reloading config, onWifi: $onWifi, firstLoad: ${cfg.firstLoad}", cfg)
        filters = FilterManager(
                blockade = blockade,
                doResolveFilterSource = doResolveFilterSource,
                doProcessFetchedFilters = doProcessFetchedFilters,
                doValidateRulesetCache = { it ->
                    it.source.id in listOf("app")
                            || it.lastFetch + cfg.cacheTTL * 1000 > System.currentTimeMillis()
                            || cfg.wifiOnly && !onWifi && !cfg.firstLoad && it.source.id == "link"
                },
                doValidateFilterStoreCache = { it ->
                    it.cache.isNotEmpty()
                            && (it.lastFetch + cfg.cacheTTL * 1000 > System.currentTimeMillis()
                            || cfg.wifiOnly && !onWifi)
                }
        )
        filters.load(ktx)
        if (filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun stop(ktx: AndroidKontext) = async(CTRL) {
        maybeStopTunnelThread(ktx)
        maybeStopVpn(ktx)
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

    fun setUrl(ktx: Kontext, url: String) = async(CTRL) {
        val cfg = Persistence.config.load(ktx)
        ktx.v("setting url, firstLoad: ${cfg.firstLoad}", url)
        filters.setUrl(ktx, url)
        if (filters.sync(ktx)) {
            ktx.v("first fetch successful, unsetting firstLoad flag")
            Persistence.config.save(cfg.copy(firstLoad = false))
        }
        filters.save(ktx)
        restartTunnelThread(ktx)
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

    fun removeFilter(ktx: Kontext, filter: Filter) = async(CTRL) {
        filters.remove(ktx, filter)
        if (filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun invalidateFilters(ktx: Kontext) = async(CTRL) {
        filters.invalidateCache(ktx)
        if(filters.sync(ktx)) {
            filters.save(ktx)
            restartTunnelThread(ktx)
        }
    }

    fun deleteAllFilters(ktx: Kontext) = async(CTRL) {
        filters.removeAll(ktx)
        if (filters.sync(ktx)) {
            restartTunnelThread(ktx)
        }
    }

    private suspend fun startVpn(ktx: AndroidKontext) {
        Result.of {
            val binding = connector.bind(ktx)
            runBlocking { binding.join() }
            binder = binding.getCompleted()
            fd = binder!!.service.turnOn(ktx)
            ktx.on(Events.BLOCKED, onBlocked)
            ktx.v("vpn started")
        }.onFailure { ex ->
            ktx.e("failed starting vpn", ex)
            onVpnClose(ktx)
        }
    }

    private fun startTunnelThread(ktx: Kontext) {
        tunnel = Tunnel(proxy, forwarder, loopback)
        tunnelThread = Thread({ tunnel.runWithRetry(ktx, fd!!) }, "tunnel-${threadCounter++}")
        tunnelThread?.start()
        ktx.v("tunnel thread started", tunnelThread!!)
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
        ktx.cancel(Events.BLOCKED, onBlocked)
        binder?.service?.turnOff(ktx)
        connector.unbind(ktx).mapError { ex -> ktx.w("failed unbinding connector", ex) }
        binder = null
        fd = null
        ktx.v("vpn stopped")
    }

    private fun restartTunnelThread(ktx: Kontext) {
        if (tunnelThread != null) {
            stopTunnelThread(ktx)
            startTunnelThread(ktx)
        }
    }

    private suspend fun restartVpn(ktx: AndroidKontext) {
        if (binder != null) {
            stopVpn(ktx)
            startVpn(ktx)
        }
    }

    private fun maybeStartTunnelThread(ktx: Kontext) = if (tunnelThread == null) {
        startTunnelThread(ktx)
    } else Unit

    private fun maybeStopTunnelThread(ktx: Kontext) = if (tunnelThread != null) {
        stopTunnelThread(ktx); true
    } else false

    private suspend fun maybeStartVpn(ktx: AndroidKontext) = if (binder == null) startVpn(ktx) else Unit

    private fun maybeStopVpn(ktx: AndroidKontext) = if (binder != null) {
        stopVpn(ktx); true
    } else false

}
