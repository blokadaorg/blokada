package tunnel

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import core.PanelActivity
import core.v
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
            v("received VpnService onClose", rejected)
            tunnelState.tunnelPermission.refresh(blocking = true)
            if (rejected || !tunnelState.tunnelPermission()) {
                tunnelState.enabled %= false
                tunnelState.active %= false
                showSnack(R.string.home_permission_error)
            } else {
                tunnelState.restart %= true
                tunnelState.active %= false
            }
        },
        onVpnConfigure = { vpn ->
            vpn.setSession(ctx.getString(R.string.branding_app_name))
                .setConfigureIntent(
                    PendingIntent.getActivity(
                        ctx, 1,
                        Intent(ctx, PanelActivity::class.java),
                        PendingIntent.FLAG_CANCEL_CURRENT
                    )
                )
        },
        createTunnel = this::createTunnel,
        createConfigurator = this::createConfigurator
    )

    private fun createConfigurator(state: CurrentTunnel, binder: ServiceBinder) = when {
        //usePausedConfigurator -> PausedVpnConfigurator(currentServers, filters)
        state.blockaVpn -> {
            BlockaVpnConfigurator(
                state.dnsServers, filterManager(), state.adblocking, state.lease!!,
                ctx.packageName
            )
        }
        else -> SimpleVpnConfigurator(state.dnsServers, filterManager())
    }

    private fun createTunnel(state: CurrentTunnel, socketCreator: () -> DatagramSocket) = when {
        state.blockaVpn -> {
            BlockaTunnel(
                state.dnsServers,
                blockade,
                tunnelConfig().powersave,
                state.adblocking,
                state.lease!!,
                state.userBoringtunPrivateKey!!,
                socketCreator
            )
        }
        else -> null
    }

}

