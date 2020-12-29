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
import repository.DnsDataSource
import service.ConnectivityService
import service.EnvironmentService
import utils.Logger
import java.net.DatagramSocket
import java.net.Socket

object EngineService {

    private var status = TunnelStatus.off()
        set(value) {
            if (field != value) {
                field = value
                onTunnelStatusChanged(value)
            }
        }

    private val log = Logger("Engine")
    private val systemTunnel = SystemTunnelService
    private val packetLoop = PacketLoopService
    private val filtering = FilteringService
    private val dnsMapper = DnsMapperService
    private val dnsService = BlockaDnsService
    private val connectivity = ConnectivityService
    private val configurator = SystemTunnelConfigurator
    private val scope = GlobalScope

    // Current state of the tunnel
    private lateinit var netCfg: NetworkSpecificConfig
    private lateinit var dns: Dns
    private var doh: Boolean = false
    private var lease: Lease? = null
    private var config: BlockaConfig? = null

    private lateinit var dnsForLibreMode: Dns
    private lateinit var dnsForPlusMode: Dns

    var onTunnelStoppedUnexpectedly = { ex: BlokadaException -> }
    var onTunnelStatusChanged = { status: TunnelStatus -> }

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
                    if (!status.restarting) {
                        packetLoop.stop()
                        status = TunnelStatus.off()
                        onTunnelStoppedUnexpectedly(it)
                    }
                }
            }
        }
    }

    suspend fun getTunnelStatus(): TunnelStatus {
        if (status.restarting) return status
        packetLoop.getStatus()?.let {
            status = TunnelStatus.connected(dns, doh, it)
        } ?: run {
            val active = systemTunnel.getStatus()
            status = if (active) {
                // Make sure to communicate DoH status too
                TunnelStatus.filteringOnly(dns, doh)
            } else TunnelStatus.off()
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
                dns = dnsForLibreMode
                doh = useDoh(dns)
                dnsMapper.setDns(dns, doh)
                if (doh) dnsService.startDnsProxy(dns)
                systemTunnel.onConfigureTunnel = { tun ->
                    configurator.forLibre(tun, dns)
                }
                val tunnelConfig = systemTunnel.open()
                packetLoop.startSlimMode(doh, dns, tunnelConfig)
            }
            // Libre mode
            lease == null -> {
                dns = dnsForLibreMode
                doh = useDoh(dns)
                dnsMapper.setDns(dns, doh)
                if (doh) dnsService.startDnsProxy(dns)
                systemTunnel.onConfigureTunnel = { tun ->
                    configurator.forLibre(tun, dns)
                }
                val tunnelConfig = systemTunnel.open()
                packetLoop.startLibreMode(doh, dns, tunnelConfig)
            }
            // Plus mode
            else -> {
                dns = dnsForPlusMode
                doh = useDoh(dns, plusMode = true)
                dnsMapper.setDns(dns, doh, plusMode = true)
                if (doh) dnsService.startDnsProxy(dns)
                systemTunnel.onConfigureTunnel = { tun ->
                    configurator.forPlus(tun, dns, lease = lease)
                }
                systemTunnel.open()
                // Packet loop is started by connectVpn()
            }
        }
        status = TunnelStatus.filteringOnly(dns, doh)
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
            useDoh = doh,
            dns = dns,
            tunnelConfig = systemTunnel.getTunnelConfig(),
            privateKey = config.privateKey,
            gateway = config.gateway
        )
        this.config = config
        status = TunnelStatus.connected(dns, doh, config.gateway.public_key)
    }

    suspend fun disconnectVpn() {
        if (!status.active && !status.restarting) throw BlokadaException("Wrong tunnel state")
        status = TunnelStatus.inProgress()
        packetLoop.stop()
        status = TunnelStatus.filteringOnly(dns, doh)
    }

    fun setNetworkConfig(cfg: NetworkSpecificConfig) {
        this.netCfg = cfg

        /**
         * The DNS server choice gets a bit complicated:
         * - useNetworkDns will force to use network-provided DNS servers (if any) and to not use DoH
         *   despite user setting (in useDoh()). If no network DNS servers were detected, then it'll
         *   use the cfg.dnsChoice after all.
         * - For Plus Mode, ignore the useNetworkDns setting, since network DNS would not resolve
         *   under the real VPN. Instead, use the useBlockaDnsInPlusMode flag (which is true by
         *   default), to safely fallback to our DNS.
         *
         * This approach may not address all user network specific problems, but I could not think
         * of a better one.
         */
        this.dnsForLibreMode = if (cfg.useNetworkDns && cfg.hasNetworkDns()) DnsDataSource.network else DnsDataSource.byId(cfg.dnsChoice)
        this.dnsForPlusMode = if (cfg.useBlockaDnsInPlusMode) DnsDataSource.blocka else this.dnsForLibreMode
    }

    suspend fun applyNetworkConfig(cfg: NetworkSpecificConfig) {
        log.w("Applying network config: $cfg")
        val shouldRestart = when {
            cfg.dnsChoice != netCfg.dnsChoice -> true
            cfg.useBlockaDnsInPlusMode != netCfg.useBlockaDnsInPlusMode -> true
            cfg.encryptDns != netCfg.encryptDns -> true
            cfg.useNetworkDns != netCfg.useNetworkDns -> true
            else -> false
        }
        setNetworkConfig(cfg)
        if (shouldRestart) restart()
        else log.v("Network config change does not require engine restart")
    }

    private fun NetworkSpecificConfig.hasNetworkDns(): Boolean {
        return connectivity.getDnsServers(this.network).isNotEmpty()
    }

    suspend fun restart() {
        val status = getTunnelStatus()
        if (status.active) {
            this.status = TunnelStatus.restarting()
            if (status.gatewayId != null) disconnectVpn()
            restartSystemTunnel(lease)
            if (status.gatewayId != null) connectVpn(config!!)
        }
    }

    suspend fun restartSystemTunnel(lease: Lease?) {
        dnsService.stopDnsProxy()
        packetLoop.stop()
        systemTunnel.close()
        log.w("Waiting after stopping system tunnel, before another start")
        delay(5000)
        startTunnel(lease)
    }

    suspend fun reloadBlockLists() {
        filtering.reload()
        restart()
    }

    suspend fun pause() {
        throw BlokadaException("TODO pause not implemented")
    }

    fun protectSocket(socket: Socket) {
        systemTunnel.protectSocket(socket)
    }

    private fun useDoh(dns: Dns, plusMode: Boolean = false): Boolean {
        return when {
            dns.id == DnsDataSource.network.id -> {
                // Only plaintext network DNS are supported currently
                false
            }
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
                dns.isDnsOverHttps() && netCfg.encryptDns
            }
        }
    }
}