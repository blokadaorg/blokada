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
        private val filterManager: FilterManager
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

/**
 * A VPN configuration for the true VPN functionality (towards blocka.net).
 */
internal class BlockaVpnConfigurator(
        private val dnsServers: List<InetSocketAddress>,
        private val filterManager: FilterManager,
        private val blockaConfig: BlockaConfig
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

        dnsServers.forEach {
            builder.addDnsServer(it.address)
        }

        // TODO: support configurable ipv6 servers - this one is cloudflare
        builder.addDnsServer("2606:4700:4700::1111")

        builder.addAddress(blockaConfig.vip4, 32)
        builder.addAddress(blockaConfig.vip6, 128)

        builder.addRoute("0.0.0.0", 0)
        builder.addRoute("::", 0)

        builder.setBlocking(true)
    }

}

interface Configurator {
    fun configure(ktx: Kontext, builder: VpnService.Builder)
}
