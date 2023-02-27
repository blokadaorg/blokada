/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import com.wireguard.android.backend.Tunnel
import com.wireguard.config.*
import com.wireguard.crypto.Key
import com.wireguard.crypto.KeyPair
import kotlinx.coroutines.delay
import model.BlokadaException
import model.Gateway
import model.Lease
import repository.AppRepository
import service.EnvironmentService
import ui.MainApplication
import utils.Logger
import java.net.InetAddress

object WgTunnel {

    private val log = Logger("WgTunnel")
    private val wgManager = MainApplication.getTunnelManager()
    private val apps = AppRepository

    private val ALLOWED_IPS = listOf(
        "::/0", "1.0.0.0/8", "2.0.0.0/8", "3.0.0.0/8", "4.0.0.0/6", "8.0.0.0/7", "11.0.0.0/8",
        "12.0.0.0/6", "16.0.0.0/4", "32.0.0.0/3", "64.0.0.0/2", "128.0.0.0/3", "160.0.0.0/5",
        "168.0.0.0/6", "172.0.0.0/12", "172.32.0.0/11", "172.64.0.0/10", "172.128.0.0/9",
        "173.0.0.0/8", "174.0.0.0/7", "176.0.0.0/4", "192.0.0.0/9", "192.128.0.0/11",
        "192.160.0.0/13", "192.169.0.0/16", "192.170.0.0/15", "192.172.0.0/14", "192.176.0.0/12",
        "192.192.0.0/10", "193.0.0.0/8", "194.0.0.0/7", "196.0.0.0/6", "200.0.0.0/5", "208.0.0.0/4",
    )

    suspend fun start(privateKey: String, lease: Lease, gateway: Gateway) {
        log.v("Starting WG tunnel for: ${gateway.country}")

        // Remove old tunnel config if any
        val tunnels = wgManager.getTunnels()
        if (tunnels.isNotEmpty()) wgManager.delete(tunnels.first())

        // Wait until tag is available
        var attempts = 0
        while (EnvironmentService.deviceTag == null && attempts++ < 3) {
            delay(2000)
        }
        val tag = EnvironmentService.deviceTag
        val dnsAddress =
            if (tag?.isNotEmpty() == true) InetAddress.getByName(getUserDnsIp(tag))
            else throw BlokadaException("Device tag is null or empty, cant start wg-go")

        log.v("Wg tunnel will use DNS address: $dnsAddress")

        val peerBuilder = Peer.Builder()
            .setPublicKey(Key.fromBase64(gateway.public_key))
            .setEndpoint(InetEndpoint.parse("${gateway.ipv4}:51820"))

        ALLOWED_IPS.forEach {
            peerBuilder.addAllowedIp(InetNetwork.parse(it))
        }

        val c = Config.Builder()
            .setInterface(
                Interface.Builder()
                .setKeyPair(KeyPair(Key.fromBase64(privateKey)))
                .addAddress(InetNetwork.parse("${lease.vip4}/32"))
                .addAddress(InetNetwork.parse("${lease.vip6}/64"))
                .addDnsServer(dnsAddress)
                .excludeApplications(apps.getPackageNamesOfAppsToBypass(forRealTunnel = true))
                .build()
            )
            .addPeer(peerBuilder.build())
        .build()

        val tunnel = wgManager.create("Blokada", c)
        wgManager.setTunnelState(tunnel, Tunnel.State.UP)
    }

    suspend fun stop() {
        log.v("Stopping WG tunnel")
        val tunnels = wgManager.getTunnels()
        if (tunnels.isNotEmpty()) wgManager.setTunnelState(tunnels.first(), Tunnel.State.DOWN)
    }

    private fun getUserDnsIp(tag: String): String {
        return if (tag.length == 6) {
            // 6 chars old tag
            "2001:678:e34:1d::${tag.substring(0, 2)}:${tag.substring(2, 6)}"
        } else {
            // 11 chars new tag
            "2001:678:e34:1d::${tag.substring(0, 3)}:${tag.substring(3, 7)}:${tag.substring(7, 11)}"
        }
    }

}