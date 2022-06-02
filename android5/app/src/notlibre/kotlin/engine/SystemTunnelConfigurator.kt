/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2021 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import android.net.VpnService
import android.os.Build
import model.BlokadaException
import model.Dns
import model.Lease
import repository.AppRepository
import ui.utils.cause
import utils.FlavorSpecific
import utils.Logger
import java.net.Inet4Address

object SystemTunnelConfigurator: FlavorSpecific {

    private val log = Logger("STConfigurator")
    private val apps = AppRepository

    fun forPlus(tun: VpnService.Builder, dns: Dns, lease: Lease) {
        log.v("Configuring VPN for Plus mode")

        log.v("Using IP: ${lease.vip4}, ${lease.vip6}")
        tun.addAddress(lease.vip4, 32)
        tun.addAddress(lease.vip6, 128)

        var index = 1
        for (address in decideDns(dns, plusMode = true)) {
            try {
                log.v("Adding DNS server: $address")
                tun.addMappedDnsServer(index++)
            } catch (ex: Exception) {
                log.e("Failed adding DNS server".cause(ex))
            }
        }

        log.v("Setting only public networks as routes for IPv4")
        IPV4_PUBLIC_NETWORKS.forEach {
            val (ip, mask) = it.split("/")
            tun.addRoute(ip, mask.toInt())
        }

        log.v("Setting all networks as routes for IPv6")
        tun.addRoute("::", 0)

        log.v("Setting MTU: $MTU")
        tun.setMtu(MTU)
        tun.setBlocking(true)
        tun.setSession("Blokada Plus")

        // To not show our VPN as a metered connection
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            tun.setMetered(false)
        }

        val bypassed = apps.getPackageNamesOfAppsToBypass(forRealTunnel = true)
        log.v("Setting bypass for ${bypassed.count()} apps")
        bypassed.forEach {
            tun.addDisallowedApplication(it)
        }
    }

    fun forLibre(tun: VpnService.Builder, dns: Dns) {
        throw BlokadaException("Libre mode not supported in this build")
    }

    fun forSlim(tun: VpnService.Builder, doh: Boolean, dns: Dns) {
        throw BlokadaException("Slim mode not supported in this build")
    }

    private fun VpnService.Builder.addMappedDnsServer(index: Int, addRoute: Boolean = false) {
        log.v("Adding mapped DNS server for IPv4")
        val template = dnsProxyDst4.copyOf()
        template[template.size - 1] = (index).toByte()
        val add = Inet4Address.getByAddress(template)
        this.addDnsServer(add)
        if (addRoute) this.addRoute(add, 32)
    }

}

internal val MTU = 1280

private val IPV4_PUBLIC_NETWORKS = listOf(
    "0.0.0.0/5", "8.0.0.0/7", "11.0.0.0/8", "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3",
    "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5", "168.0.0.0/6", "172.0.0.0/12",
    "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9", "173.0.0.0/8", "174.0.0.0/7",
    "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11", "192.160.0.0/13", "192.169.0.0/16",
    "192.170.0.0/15", "192.172.0.0/14", "192.176.0.0/12", "192.192.0.0/10",
    "193.0.0.0/8", "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4"
)
