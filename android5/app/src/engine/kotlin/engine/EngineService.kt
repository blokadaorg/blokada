/*
 * This file is part of Blokada.
 *
 * Blokada is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Blokada is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
 *
 * Copyright © 2020 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package engine

import com.cloudflare.app.boringtun.BoringTunJNI
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.*
import newengine.BlockaDnsService
import service.EnvironmentService
import service.PersistenceService
import utils.Logger
import java.net.DatagramSocket
import java.net.Socket

object EngineService {

    private var status = TunnelStatus.off()

    private val log = Logger("Engine")
    private val systemTunnel = SystemTunnelService
    private val packetLoop = PacketLoopService
    private val filtering = FilteringService
    private val dnsMapper = DnsMapperService
    private val dnsService = BlockaDnsService
    private val configurator = SystemTunnelConfigurator
    private val scope = GlobalScope

    private var lease: Lease? = null
    private var config: BlockaConfig? = null

    private lateinit var dns: Dns
    private lateinit var dnsForPlusMode: Dns

    var onTunnelStoppedUnexpectedly = { ex: BlokadaException -> }

    fun setup() {
        JniService.setup()

        packetLoop.onCreateSocket = {
            val socket = DatagramSocket()
            systemTunnel.protectSocket(socket)
            socket
        }

        packetLoop.onStoppedUnexpectedly = {
            scope.launch {
                systemTunnel.close()
                status = TunnelStatus.off()
                onTunnelStoppedUnexpectedly(BlokadaException("PacketLoop stopped"))
            }
        }

        systemTunnel.onTunnelClosed = { ex: BlokadaException? ->
            ex?.let {
                scope.launch {
                    packetLoop.stop()
                    status = TunnelStatus.off()
                    onTunnelStoppedUnexpectedly(it)
                }
            }
        }
    }

    suspend fun getTunnelStatus(): TunnelStatus {
        packetLoop.getStatus()?.let {
            status = TunnelStatus.connected(it)
        } ?: run {
            status = systemTunnel.getStatus()
            if (status.active) {
                // Make sure to communicate DoH status too
                status = TunnelStatus.filteringOnly(useDoh(dns))
            }
        }
        return status
    }

    suspend fun goToBackground() {
        systemTunnel.unbind()
    }

    suspend fun newKeypair(): Pair<PrivateKey, PublicKey> {
        val secret = BoringTunJNI.x25519_secret_key()
        val public = BoringTunJNI.x25519_public_key(secret)
        val secretString = BoringTunJNI.x25519_key_to_base64(secret)
        val publicString = BoringTunJNI.x25519_key_to_base64(public)
        return secretString to publicString
    }

    suspend fun startTunnel(lease: Lease?) {
        status = TunnelStatus.inProgress()
        this.lease = lease

        when {
            // Slim mode
            lease == null && EnvironmentService.isSlim() -> {
                val useDoh = useDoh(dns)
                dnsMapper.setDns(dns, useDoh)
                if (useDoh) dnsService.startDnsProxy(dns)
//                systemTunnel.onConfigureTunnel = { tun ->
//                    configurator.forSlim(tun, useDoh, dns)
//                }
//                systemTunnel.open()
//                status = TunnelStatus.filteringOnly(useDoh)
                systemTunnel.onConfigureTunnel = { tun ->
                    val ipv6 = PersistenceService.load(LocalConfig::class).ipv6
                    configurator.forLibre(tun, dns, ipv6)
                }
                val tunnelConfig = systemTunnel.open()
                packetLoop.startSlimMode(useDoh, dns, tunnelConfig)
                status = TunnelStatus.filteringOnly(useDoh)
            }
            // Libre mode
            lease == null -> {
                val useDoh = useDoh(dns)
                dnsMapper.setDns(dns, useDoh)
                if (useDoh) dnsService.startDnsProxy(dns)
                systemTunnel.onConfigureTunnel = { tun ->
                    val ipv6 = PersistenceService.load(LocalConfig::class).ipv6
                    configurator.forLibre(tun, dns, ipv6)
                }
                val tunnelConfig = systemTunnel.open()
                packetLoop.startLibreMode(useDoh, dns, tunnelConfig)
                status = TunnelStatus.filteringOnly(useDoh)
            }
            // Plus mode
            else -> {
                val useDoh = useDoh(dnsForPlusMode, plusMode = true)
                dnsMapper.setDns(dnsForPlusMode, useDoh, plusMode = true)
                if (useDoh) dnsService.startDnsProxy(dnsForPlusMode)
                systemTunnel.onConfigureTunnel = { tun ->
                    val ipv6 = PersistenceService.load(LocalConfig::class).ipv6
                    configurator.forPlus(tun, ipv6, dnsForPlusMode, lease = lease)
                }
                systemTunnel.open()
                status = TunnelStatus.filteringOnly(useDoh)
            }
        }
    }

    suspend fun stopTunnel() {
        status = TunnelStatus.inProgress()
        dnsService.stopDnsProxy()
        packetLoop.stop()
        systemTunnel.close()
        status = TunnelStatus.off()
    }

    suspend fun connectVpn(config: BlockaConfig) {
        if (!status.active) throw BlokadaException("Wrong tunnel state")
        if (config.gateway == null) throw BlokadaException("No gateway configured")
        status = TunnelStatus.inProgress()
        packetLoop.startPlusMode(
            useDoh = useDoh(dnsForPlusMode, plusMode = true), dnsForPlusMode,
            tunnelConfig = systemTunnel.getTunnelConfig(),
            privateKey = config.privateKey,
            gateway = config.gateway
        )
        this.config = config
        status = TunnelStatus.connected(config.gateway.public_key)
    }

    suspend fun disconnectVpn() {
        if (!status.active) throw BlokadaException("Wrong tunnel state")
        status = TunnelStatus.inProgress()
        packetLoop.stop()
        status = TunnelStatus.filteringOnly(useDoh(dns))
    }

    fun setDns(dns: Dns, dnsForPlusMode: Dns? = null) {
        this.dns = dns
        this.dnsForPlusMode = dnsForPlusMode ?: dns
    }

    suspend fun changeDns(dns: Dns, dnsForPlusMode: Dns? = null) {
        log.w("Requested to change DNS")
        this.dns = dns
        this.dnsForPlusMode = dnsForPlusMode ?: dns
        restart()
    }

    suspend fun reloadBlockLists() {
        filtering.reload()
        restart()
    }

    suspend fun restart() {
        val status = getTunnelStatus()
        if (status.active) {
            if (status.gatewayId != null) disconnectVpn()
            restartSystemTunnel(lease)
            if (status.gatewayId != null) connectVpn(config!!)
        }
    }

    suspend fun restartSystemTunnel(lease: Lease?) {
        stopTunnel()
        log.w("Waiting after stopping system tunnel, before another start")
        delay(5000)
        startTunnel(lease)
    }

    suspend fun pause() {
        throw BlokadaException("TODO pause not implemented")
    }

    fun protectSocket(socket: Socket) {
        systemTunnel.protectSocket(socket)
    }

    private fun useDoh(dns: Dns, plusMode: Boolean = false): Boolean {
        return when {
            plusMode && dns.plusIps != null -> {
                // If plusIps are set, they will point to a clear text DNS, because the plus mode
                // VPN itself is encrypting everything, so there is no need to encrypt DNS.
                log.w("Using clear text as DNS defines special IPs for plusMode")
                false
            }
            dns.isDnsOverHttps() && !dns.canUseInCleartext -> {
                // If DNS supports only DoH and no clear text, we are forced to use it
                log.w("Forcing DoH as selected DNS does not support clear text")
                true
            }
            else -> {
                dns.isDnsOverHttps() && PersistenceService.load(LocalConfig::class).useDnsOverHttps
            }
        }
    }
}