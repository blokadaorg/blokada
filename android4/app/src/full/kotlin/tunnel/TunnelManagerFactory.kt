package tunnel

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import core.PanelActivity
import org.blokada.R
import java.net.DatagramSocket
import java.util.*

internal class TunnelManagerFactory(
        private val ctx: Context,
        private val tunnelState: core.Tunnel,
        private val blockade: Blockade,
        private val filterManager: () -> FilterManager,
        private val tunnelConfig: () -> TunnelConfig,
        private val forwarder: Forwarder = Forwarder(),
        private val loopback: LinkedList<Triple<ByteArray, Int, Int>> = LinkedList()
) {

    fun create() = TunnelManager(
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

    private fun createConfigurator(state: CurrentTunnel, binder: ServiceBinder) = when {
        //usePausedConfigurator -> PausedVpnConfigurator(currentServers, filters)
        state.blockaVpn -> {
            BlockaVpnConfigurator(state.dnsServers, filterManager(), state.adblocking, state.lease!!,
                    ctx.packageName)
        }
        !state.adblocking -> SimpleVpnConfigurator(state.dnsServers, filterManager())
        else -> DnsVpnConfigurator(state.dnsServers, filterManager(), ctx.packageName)
    }

    private fun createTunnel(state: CurrentTunnel, socketCreator: () -> DatagramSocket) = when {
        state.blockaVpn -> {
            BlockaTunnel(state.dnsServers, blockade, tunnelConfig().powersave, state.adblocking, state.lease!!,
                    state.userBoringtunPrivateKey!!, socketCreator)
        }
        !state.adblocking -> null
        else -> {
            val proxy = createProxy(state, socketCreator)
            DnsTunnel(proxy!!, tunnelConfig().powersave, forwarder, loopback)
        }
    }

    private fun createProxy(state: CurrentTunnel, socketCreator: () -> DatagramSocket) = when {
        state.blockaVpn -> null // in VPN mode we don't use proxy class
        else -> DnsProxy(state.dnsServers, blockade, forwarder, loopback, doCreateSocket = socketCreator)
    }
}

