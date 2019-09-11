package tunnel

import blocka.CurrentLease
import java.io.FileDescriptor
import java.net.InetSocketAddress


data class TunnelConfig(
        val tunnelEnabled: Boolean = false,
        val adblocking: Boolean = true,
        val wifiOnly: Boolean = true,
        val firstLoad: Boolean = true,
        val powersave: Boolean = false,
        val dnsFallback: Boolean = true,
        val report: Boolean = false, // TODO: gone from here
        var filtersUrl: String? = null,
        val cacheTTL: Long = 86400
)

data class CurrentTunnel(
        val dnsServers: List<InetSocketAddress> = emptyList(),
        val adblocking: Boolean = false,
        val blockaVpn: Boolean = false,
        val lease: CurrentLease? = null,
        val userBoringtunPrivateKey: String? = null
) {
    override fun toString(): String {
        return "CurrentTunnel(dnsServers=$dnsServers, adblocking=$adblocking, blockaVpn=$blockaVpn, lease=$lease)"
    }
}

data class TunnelDescriptor(
        val tunnel: Tunnel,
        val thread: Thread,
        val fd: FileDescriptor,
        val binder: ServiceBinder
)
