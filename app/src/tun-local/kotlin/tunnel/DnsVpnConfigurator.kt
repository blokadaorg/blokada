package tunnel

import android.net.VpnService
import core.Kontext
import core.Result
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.util.*

/**
 * A VPN tunnel configuration that only redirects DNS requests.
 */
internal class DnsVpnConfigurator(
        private val dnsServers: List<InetSocketAddress>,
        private val filterManager: FilterManager,
        private val packageName: String
): Configurator {

    private var dnsIndex = 1

    override fun configure(ktx: Kontext, builder: VpnService.Builder) {
        var format: String? = null

        // Those are TEST-NET IP ranges from RFC5735, so that we don't collide.
        for (prefix in arrayOf("203.0.113", "198.51.100", "192.0.2")) {
            try {
                builder.addAddress("$prefix.1", 24)
            } catch (e: IllegalArgumentException) {
                continue
            }

            format = "$prefix.%d"
            break
        }

        if (format == null) {
            // If no subnet worked, just go with something safe.
            builder.addAddress("192.168.50.1", 24)
        }

        // Also a special subnet (2001:DB8::/32), from RFC3849. Meant for documentation use.
        var ipv6Template: ByteArray? = byteArrayOf(32, 1, 13, (184 and 0xFF).toByte(),
                0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

        if (dnsServers.any { it.getAddress() is Inet6Address }) {
            try {
                val address = Inet6Address.getByAddress(ipv6Template)
                builder.addAddress(address, 120)
            } catch (e: Exception) {
                ktx.e("failed adding ipv6 address", e)
                ipv6Template = null
            }
        } else {
            ipv6Template = null
        }

        dnsIndex = 1
        for (address in dnsServers) {
            try {
                builder.addDnsServer(format, ipv6Template, address)
            } catch (e: Exception) {
                ktx.e("failed adding dns server", e)
            }
        }

        builder.addDisallowedApplication(packageName)
        filterManager.getWhitelistedApps(ktx).forEach {
            builder.addDisallowedApplication(it)
        }

        // People kept asking why GPlay doesnt work
        Result.of { builder.addDisallowedApplication("com.android.vending") }

        builder.setBlocking(true)
    }

    private fun VpnService.Builder.addDnsServer(format: String?, ipv6Template: ByteArray?,
                                                            address: InetSocketAddress) = when {
        address.getAddress() is Inet6Address && ipv6Template != null -> {
            ipv6Template[ipv6Template.size - 1] = (++dnsIndex).toByte()
            val ipv6Address = Inet6Address.getByAddress(ipv6Template)
            this.addDnsServer(ipv6Address)
        }
        address.getAddress() is Inet4Address && format != null -> {
            val alias = String.format(Locale.ENGLISH, format, ++dnsIndex)
            this.addDnsServer(alias)
            this.addRoute(alias, 32)
        }
        else -> Unit
    }
}

/**
 * A VPN tunnel configuration that forwards nothing to the tunnel.
 * Used when functionality should be disabled, but the tunnel should be on.
 */
internal class PausedVpnConfigurator(
        private val dnsServers: List<InetSocketAddress>,
        private val filterManager: FilterManager
): Configurator {

    override fun configure(ktx: Kontext, builder: VpnService.Builder) {
        for (address in dnsServers) {
            try {
                builder.addDnsServer(address.getAddress())
            } catch (e: Exception) {
                ktx.e("failed adding dns server", e)
            }
        }

        filterManager.getWhitelistedApps(ktx).forEach {
            builder.addDisallowedApplication(it)
        }

        // People kept asking why GPlay doesnt work
        Result.of { builder.addDisallowedApplication("com.android.vending") }

        builder.addAddress("203.0.113.0", 32)
        builder.setBlocking(true)
    }

}

// A TEST-NET IP range from RFC5735
private const val dnsProxyDst4String = "203.0.113.0"
val dnsProxyDst4 = Inet4Address.getByName(dnsProxyDst4String).address!!

// A special test subnet from RFC3849
private const val dnsProxyDst6String = "2001:DB8::"
val dnsProxyDst6 = Inet6Address.getByName(dnsProxyDst6String).address!!

/**
 * A VPN configuration for the true VPN functionality (towards blocka.net).
 */
internal class BlockaVpnConfigurator(
        private val dnsServers: List<InetSocketAddress>,
        private val filterManager: FilterManager,
        private val blockaConfig: BlockaConfig,
        private val packageName: String
): Configurator {

    private var dnsIndex = 1

    override fun configure(ktx: Kontext, builder: VpnService.Builder) {
        // Set local IP addresses for the DNS proxy so we can easily catch them for inspection
        dnsIndex = 0
        for (address in dnsServers) {
            try {
                ktx.v("adding dns server $address")
                if (blockaConfig.adblocking) builder.addMappedDnsServer(address)
                else builder.addDnsServer(address.address)
            } catch (e: Exception) {
                ktx.e("failed adding dns server $address", e)
            }
        }

        // TODO: support configurable ipv6 servers - this one is cloudflare
        // This means ad blocking does not work for ipv6 currently
        //builder.addDnsServer("2606:4700:4700::1111")

        builder.addDisallowedApplication(packageName)
        filterManager.getWhitelistedApps(ktx).forEach {
            builder.addDisallowedApplication(it)
        }

        ktx.v("vpn addresses: ${blockaConfig.vip4}, ${blockaConfig.vip6}")
        builder.addAddress(blockaConfig.vip4, 32)
        builder.addAddress(blockaConfig.vip6, 128)

        IPV4_PUBLIC_NETWORKS.forEach {
            val (ip, mask) = it.split("/")
            builder.addRoute(ip, mask.toInt())
        }
        //builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)

        builder.setBlocking(true)
        builder.setMtu(1280)
    }

    private fun VpnService.Builder.addMappedDnsServer(address: InetSocketAddress) {
        when {
            address.address is Inet6Address -> {
                val template = dnsProxyDst6.copyOf()
                template[template.size - 1] = (++dnsIndex).toByte()
                this.addDnsServer(Inet6Address.getByAddress(template))
            }
            address.address is Inet4Address -> {
                val template = dnsProxyDst4.copyOf()
                template[template.size - 1] = (++dnsIndex).toByte()
                this.addDnsServer(Inet4Address.getByAddress(template))
            }
            else -> Unit
        }
    }
}

interface Configurator {
    fun configure(ktx: Kontext, builder: VpnService.Builder)
}

private val IPV4_PUBLIC_NETWORKS = listOf(
        "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3",
        "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6", "172.0.0.0/12",
        "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9", "173.0.0.0/8", "174.0.0.0/7",
        "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16",
        "192.170.0.0/15", "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10",
        "193.0.0.0/8", "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4"
)
