package core

import blocka.BlockaVpnState
import blocka.blockaVpnMain
import com.github.salomonbrys.kodein.instance
import core.bits.menu.MENU_CLICK_BY_NAME
import gs.property.Device
import gs.property.Repo
import kotlinx.coroutines.experimental.async
import kotlinx.coroutines.experimental.newSingleThreadContext
import kotlinx.coroutines.experimental.runBlocking
import org.blokada.R
import tunnel.TunnelConfig
import tunnel.showSnack
import tunnel.tunnelMain
import java.net.InetSocketAddress

private val context = newSingleThreadContext("entrypoint") + logCoroutineExceptions()

val entrypoint = runBlocking { async(context) { Entrypoint() }.await() }

class Entrypoint {

    private val ctx by lazy { getActiveContext()!! }
    private val di by lazy { ctx.ktx("entrypoint").di() }
    private val repo by lazy { di.instance<Repo>() }
    private val device by lazy { di.instance<Device>() }
    private val dns by lazy { di.instance<Dns>() }
    private val tunnelState by lazy { di.instance<Tunnel>() }

    private var syncRequests = 0
    private var syncBlocka = false
    private var forceSyncBlocka = false

    private fun requestSync(blocka: Boolean = false, force: Boolean = false) {
        syncRequests++
        syncBlocka = syncBlocka || blocka
        forceSyncBlocka = forceSyncBlocka || force
        async(context) {
            if (--syncRequests == 0) {
                v("syncing after recent changes")
                tunnelState.tunnelState %= if (tunnelState.enabled()) TunnelState.ACTIVATING else TunnelState.DEACTIVATING
                try {
                    if (forceSyncBlocka) blockaVpnMain.sync().await()
                    else if (syncBlocka) blockaVpnMain.syncIfNeeded().await()
                    tunnelMain.sync().await()
                } catch (ex: Exception) {
                    e("failed syncing after recent changes", ex)
                }
                tunnelState.tunnelState %= if (tunnelState.enabled()) TunnelState.ACTIVE else TunnelState.DEACTIVATED
                tunnelState.active %= device.connected()
                syncBlocka = false
                forceSyncBlocka = false
            }
        }
    }

    fun onAppStarted() = async(context) {
        v("onAppStarted")
        if(tunnelState.enabled()) onEnableTun()
        blockaVpnMain.sync(showErrorToUser = false).await()
        tunnelMain.sync()
    }

    fun onEnableTun() = async(context) {
        v("onEnableTun")

        val config = get(TunnelConfig::class.java)
        var isAdblocking = config.adblocking
        val isDns = dns.enabled()
        val isBlockaVpn = get(BlockaVpnState::class.java).enabled
        if (!isAdblocking && !isDns && !isBlockaVpn) {
            if (Product.current(ctx) == Product.FULL) {
                isAdblocking = true
                tunnelMain.setTunnelConfiguration(config.copy(tunnelEnabled = true, adblocking = isAdblocking))
                requestSync(blocka = true)
            } else {
                if (dns.hasCustomDnsSelected()) {
                    dns.enabled %= true
                    tunnelMain.setTunnelConfiguration(config.copy(tunnelEnabled = true, adblocking = isAdblocking))
                    requestSync(blocka = true)
                } else {
                    showSnack(R.string.menu_dns_select.res())
                    emit(MENU_CLICK_BY_NAME, R.string.panel_section_advanced_dns.res())
                    tunnelState.enabled %= false
                }
            }
        } else {
            tunnelMain.setTunnelConfiguration(config.copy(tunnelEnabled = true, adblocking = isAdblocking))
            requestSync(blocka = true)
        }
    }

    fun onDisableTun() = async(context) {
        v("onDisableTun")
        val config = get(TunnelConfig::class.java)
        tunnelMain.setTunnelConfiguration(config.copy(tunnelEnabled = false))
        requestSync()
    }

    fun onVpnSwitched(on: Boolean) = async(context) {
        v("onVpnSwitched", on)
        try {
            if (on) {
                blockaVpnMain.enable().await()
                requestSync(blocka = true, force = true)
            }
            else if (shouldPause(blockaEnabled = on)) {
                blockaVpnMain.disable().await()
                tunnelState.enabled %= false
            }
            else {
                blockaVpnMain.disable().await()
                requestSync()
            }
        } catch (ex: Exception) {
            emit(MENU_CLICK_BY_NAME, R.string.menu_vpn.res())
        }
    }

    fun onSwitchAdblocking(adblocking: Boolean) = async(context) {
        v("onSwitchAdblocking")
        tunnelMain.setAdblocking(adblocking)
        if (shouldPause(adblocking = adblocking)) tunnelState.enabled %= false
        else requestSync()
    }

    fun onChangeTunnelConfig(tunnelConfig: TunnelConfig) = async(context) {
        v("onChangeTunnelConfig")
        tunnelMain.setTunnelConfiguration(tunnelConfig)
        requestSync()
    }

    fun onSwitchDnsEnabled(enabled: Boolean) = async(context) {
        v("onSwitchDnsEnabled")
        if (enabled && !dns.hasCustomDnsSelected()) {
            w("tried to enable DNS while no custom DNS is selected, ignoring")
        } else {
            dns.enabled %= enabled
            tunnelMain.setNetworkConfiguration(dns.dnsServers(), device.onWifi())
            if (shouldPause(dnsEnabled = enabled)) tunnelState.enabled %= false
            else requestSync()
        }
    }

    fun onDnsServersChanged(dnsServers: List<InetSocketAddress>) = async(context) {
        v("onDnsServersChanged")
        tunnelMain.setNetworkConfiguration(dnsServers, device.onWifi())
        requestSync()
    }

    fun onSwitchedWifi(onWifi: Boolean) = async(context) {
        v("onSwitchedWifi")
        tunnelMain.setNetworkConfiguration(dns.dnsServers(), onWifi)
        requestSync()
    }

    fun onAccountChanged() = async(context) {
        v("onAccountChanged")
        requestSync(blocka = true, force = true)
//        blockaVpnMain.sync().await()
//        tunnelMain.sync()
    }

    fun onGatewayDeselected() = async(context) {
        v("onGatewayDeselected")
        blockaVpnMain.disable()
        requestSync()
    }

    fun onGatewaySelected(gatewayId: String) = async(context) {
        v("onGatewaySelected")
        blockaVpnMain.setGatewayIfOk(gatewayId).await()
        onVpnSwitched(true)
    }

    private fun shouldPause(
            adblocking: Boolean = get(TunnelConfig::class.java).adblocking,
            blockaEnabled: Boolean = get(BlockaVpnState::class.java).enabled,
            dnsEnabled: Boolean = dns.enabled()
    ) = !dnsEnabled && !blockaEnabled && !adblocking

    fun onWentOnline() = async(context) {
        v("onWentOnline")
        repo.content.refresh()
        requestSync()
    }

    fun onFiltersChanged() = async(context) {
        v("onFiltersChanged")
        requestSync()
    }

    fun onSaveFilter(filters: List<tunnel.Filter>) = async(context) {
        v("onSaveFilter")
        tunnelMain.putFilters(filters)
        requestSync()
    }

    fun onSaveFilter(filter: tunnel.Filter) = async(context) {
        v("onSaveFilter")
        tunnelMain.putFilter(filter)
        requestSync()
    }

    fun onRemoveFilter(filter: tunnel.Filter) = async(context) {
        v("onRemoveFilter")
        tunnelMain.removeFilter(filter)
        requestSync()
    }

    fun onInvalidateFilters() = async(context) {
        v("onInvalidateFilters")
        tunnelMain.invalidateFilters()
        requestSync()
    }

    fun onDeleteAllFilters() = async(context) {
        v("onDeleteAllFilters")
        tunnelMain.deleteAllFilters()
        requestSync()
    }

    fun onSetFiltersUrl(url: String) = async(context) {
        v("onSetFiltersUrl")
        tunnelMain.setFiltersUrl(url)
        requestSync()
    }

}
