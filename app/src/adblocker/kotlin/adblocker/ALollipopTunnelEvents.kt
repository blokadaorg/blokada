/* Copyright (C) 2017 Karsen Gauss <a@kar.gs>
 *
 * Derived from DNS66:
 * Copyright (C) 2016 Julian Andres Klode <jak@jak-linux.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * Contributions shall also be provided under any later versions of the
 * GPL.
 */
package adblocker

import android.annotation.TargetApi
import android.content.Context
import android.net.VpnService
import com.github.salomonbrys.kodein.instance
import core.Dns
import core.Filters
import filter.FilterSourceApp
import gs.environment.Journal
import gs.environment.hasIpV6Servers
import gs.environment.inject
import tunnel.ITunnelEvents
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress
import java.util.*

@TargetApi(21)
internal class ALollipopTunnelEvents(
        private val ctx: Context,
        private val onRevoked: () -> Unit = {}
) : ITunnelEvents {

    private val dns by lazy { ctx.inject().instance<Dns>() }
    private val f by lazy { ctx.inject().instance<Filters>() }
    private val j by lazy { ctx.inject().instance<Journal>() }

    private var dnsIndex = 1

    override fun configure(builder: VpnService.Builder): Long {
        var format: String? = null

        // Those are TEST-NET IP ranges from RFC5735, so that we don't collide.
        for (prefix in arrayOf("203.0.113", "198.51.100", "192.0.2")) {
            try {
                builder.addAddress(prefix + ".1", 24)
            } catch (e: IllegalArgumentException) {
                continue
            }

            format = prefix + ".%d"
            break
        }

        if (format == null) {
            // If no subnet worked, just go with something safe.
            builder.addAddress("192.168.50.1", 24)
        }

        // Also a special subnet (2001:DB8::/32), from RFC3849. Meant for documentation use.
        var ipv6Template: ByteArray? = byteArrayOf(32, 1, 13, (184 and 0xFF).toByte(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

        if (hasIpV6Servers(dns.dnsServers())) {
            try {
                val address = Inet6Address.getByAddress(ipv6Template)
                builder.addAddress(address, 120)
            } catch (e: Exception) {
                j.log(e)
                ipv6Template = null
            }
        } else {
            ipv6Template = null
        }

        dnsIndex = 1
        for (address in dns.dnsServers()) {
            try {
                builder.addDnsServer(format, ipv6Template, address)
            } catch (e: Exception) {
                j.log(e)
            }
        }

        f.filters().filter { it.whitelist && it.active && it.source is FilterSourceApp }.forEach {
            builder.addDisallowedApplication(it.source.toUserInput())
        }

        // People kept asking why GPlay doesnt work
        try { builder.addDisallowedApplication("com.android.vending") } catch (e: Exception) {}

        builder.setBlocking(true)
        return 0L
    }

    private fun VpnService.Builder.addDnsServer(format: String?, ipv6Template: ByteArray?,
                                                address: InetAddress) {
        when {
            address is Inet6Address && ipv6Template != null -> {
                ipv6Template[ipv6Template.size - 1] = (++dnsIndex).toByte()
                val ipv6Address = Inet6Address.getByAddress(ipv6Template)
                this.addDnsServer(ipv6Address)
            }
            address is Inet4Address && format != null -> {
                val alias = String.format(Locale.ENGLISH, format, ++dnsIndex)
                this.addDnsServer(alias)
                this.addRoute(alias, 32)
            }
        }
    }

    override fun revoked() {
        onRevoked()
    }
}
