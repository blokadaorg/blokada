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

import com.cloudflare.app.boringtun.BoringTunJNI
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.*
import newengine.BlockaDnsService
import repository.DnsDataSource
import service.ConnectivityService
import service.EnvironmentService
import service.VpnPermissionService
import utils.Logger
import ui.utils.cause
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.Socket

object EngineService {

    private val log = Logger("Engine")
    private val systemTunnel = SystemTunnelService
    private val packetLoop = PacketLoopService
    private val filtering = FilteringService
    private val dnsMapper = DnsMapperService
    private val dnsService = BlockaDnsService
    private val configurator = SystemTunnelConfigurator
    private val vpnPerm = VpnPermissionService
    private val scope = GlobalScope

    private lateinit var config: EngineConfiguration
        @Synchronized set
        @Synchronized get

    private val state = EngineState()

    fun setup(network: NetworkSpecificConfig, user: BlockaConfig) {
        log.v("Engine initializing")
        JniService.setup()

        packetLoop.onCreateSocket = {
            val socket = DatagramSocket()
            systemTunnel.protectSocket(socket)
            socket
        }

        packetLoop.onStoppedUnexpectedly = {
            scope.launch {
                state.error(BlokadaException("PacketLoop stopped"))
                stopAll()
            }
        }

        systemTunnel.onTunnelClosed = { ex: BlokadaException? ->
            ex?.let {
                scope.launch {
                    if (!state.isRestarting()) {
                        state.error(BlokadaException("PacketLoop stopped"))
                        stopAll()
                    }
                }
            }
        }

        config = EngineConfiguration.new(network, user)
    }

    suspend fun updateConfig(network: NetworkSpecificConfig? = null, user: BlockaConfig? = null) {
        log.v("Updating engine config")

        network?.let {
            config = config.newNetworkConfig(network)
            reload(config)
        }

        user?.let {
            config = config.newUserConfig(user)
            reload(config)
        }
    }

    private suspend fun reload(config: EngineConfiguration, force: Boolean = false) {
        log.v("Reloading engine, config: $config for ${config.network.network}")

        when {
            state.isInProgress() -> {
                log.w("Reloading engine already in progress, ignoring")
                return
            }
            !force && config == state.currentConfig -> {
                log.v("Reloading engine unnecessary, ignoring")
                return
            }
        }

        val wasActive = state.tunnel.active

        state.restarting()

        try {
            if (wasActive) stopAll()

            when {
                !config.tunnelEnabled -> state.stopped(config)
                !vpnPerm.hasPermission() -> {
                    log.w("No VPN permissions, engine stopped")
                    state.stopped(config.copy(tunnelEnabled = false))
                }
                else -> startAll(config)
            }

            if (this.config != config) {
                log.v("Another reload was queued, executing")
                reload(this.config)
            }
        } catch (ex: Exception) {
            log.e("Engine reload failed".cause(ex))
            state.error(ex)
            stopAll()
            throw ex
        }
    }

    private suspend fun startAll(config: EngineConfiguration) {
        state.inProgress()
        config.run {
            when {
                // Plus mode
                isPlusMode() -> {
                    dnsMapper.setDns(dns, doh, plusMode = true)
                    if (doh) dnsService.startDnsProxy(dns)
                    systemTunnel.onConfigureTunnel = { tun ->
                        configurator.forPlus(tun, dns, lease = config.lease())
                    }
                    systemTunnel.open()
                    packetLoop.startPlusMode(
                        useDoh = doh,
                        dns = dns,
                        tunnelConfig = systemTunnel.getTunnelConfig(),
                        privateKey = config.privateKey,
                        gateway = config.gateway()
                    )
                    state.plusMode(config)
                }
                // Slim mode
                EnvironmentService.isSlim() -> {
                    dnsMapper.setDns(dns, doh)
                    if (doh) dnsService.startDnsProxy(dns)
                    systemTunnel.onConfigureTunnel = { tun ->
                        configurator.forLibre(tun, dns)
                    }
                    val tunnelConfig = systemTunnel.open()
                    packetLoop.startSlimMode(doh, dns, tunnelConfig)
                    state.libreMode(config)
                }
                // Libre mode
                else -> {
                    dnsMapper.setDns(dns, doh)
                    if (doh) dnsService.startDnsProxy(dns)
                    systemTunnel.onConfigureTunnel = { tun ->
                        configurator.forLibre(tun, dns)
                    }
                    val tunnelConfig = systemTunnel.open()
                    packetLoop.startLibreMode(doh, dns, tunnelConfig)
                    state.libreMode(config)
                }
            }
        }
    }

    private suspend fun stopAll() {
        state.inProgress()
        packetLoop.stop()
        dnsService.stopDnsProxy()
        systemTunnel.close()
        log.w("Waiting after stopping system tunnel, before another start")
        delay(4000)
        state.stopped()
    }

    suspend fun reloadBlockLists() {
        filtering.reload()
        reload(config, force = true)
    }

    suspend fun forceReload() {
        reload(config, force = true)
    }

    fun getTunnelStatus(): TunnelStatus {
        return state.tunnel
    }

    fun setOnTunnelStatusChangedListener(onTunnelStatusChanged: (TunnelStatus) -> Unit) {
        state.onTunnelStatusChanged = onTunnelStatusChanged
    }

    fun goToBackground() {
        systemTunnel.unbind()
    }

    fun newKeypair(): Pair<PrivateKey, PublicKey> {
        val secret = BoringTunJNI.x25519_secret_key()
        val public = BoringTunJNI.x25519_public_key(secret)
        val secretString = BoringTunJNI.x25519_key_to_base64(secret)
        val publicString = BoringTunJNI.x25519_key_to_base64(public)
        return secretString to publicString
    }

    fun protectSocket(socket: Socket) {
        systemTunnel.protectSocket(socket)
    }


}

private data class EngineConfiguration(
    val tunnelEnabled: Boolean,
    val dns: Dns,
    val doh: Boolean,
    val privateKey: PrivateKey,
    val gateway: Gateway?,
    val lease: Lease?,
    var networkDns: List<InetAddress>,
    val forceLibreMode: Boolean,

    val network: NetworkSpecificConfig,
    val user: BlockaConfig
) {

    fun isPlusMode() = gateway != null
    fun lease() = lease!!
    fun gateway() = gateway!!

    fun newUserConfig(user: BlockaConfig) = new(network, user)
    fun newNetworkConfig(network: NetworkSpecificConfig) = new(network, user)

    companion object {
        fun new(network: NetworkSpecificConfig, user: BlockaConfig): EngineConfiguration {
            val (dnsForLibre, dnsForPlus) = decideDnsForNetwork(network)
            val plusMode = decidePlusMode(dnsForPlus, user, network)
            val dns = if (plusMode) dnsForPlus else dnsForLibre

            return EngineConfiguration(
                tunnelEnabled = user.tunnelEnabled,
                dns = dns,
                doh = decideDoh(dns, plusMode, network.encryptDns),
                privateKey = user.privateKey,
                gateway = if (plusMode) user.gateway else null,
                lease = if (plusMode) user.lease else null,
                networkDns = if (network.useNetworkDns) ConnectivityService.getActiveNetworkDns() else emptyList(),
                forceLibreMode = network.forceLibreMode,
                network = network,
                user = user
            )
        }

        private fun decideDnsForNetwork(n: NetworkSpecificConfig): Pair<Dns, Dns> {
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

            // Here we assume the network we work with is the currently active network
            val forLibre = if (n.useNetworkDns && ConnectivityService.getActiveNetworkDns().isNotEmpty()) {
                DnsDataSource.network
            } else {
                DnsDataSource.byId(n.dnsChoice)
            }

            val forPlus = if (n.useBlockaDnsInPlusMode) DnsDataSource.blocka else forLibre

            return forLibre to forPlus
        }

        private fun decidePlusMode(dns: Dns, user: BlockaConfig, network: NetworkSpecificConfig) = when {
            !user.tunnelEnabled -> false
            !user.vpnEnabled -> false
            user.lease == null -> false
            user.gateway == null -> false
            dns == DnsDataSource.network -> {
                // Network provided DNS are likely not accessibly within the VPN.
                false
            }
            network.forceLibreMode -> false
            else -> true
        }

        private fun decideDoh(dns: Dns, plusMode: Boolean, encryptDns: Boolean) = when {
            dns.id == DnsDataSource.network.id -> {
                // Only plaintext network DNS are supported currently
                false
            }
            plusMode && dns.plusIps != null -> {
                // If plusIps are set, they will point to a clear text DNS, because the plus mode
                // VPN itself is encrypting everything, so there is no need to encrypt DNS.
                false
            }
            dns.isDnsOverHttps() && !dns.canUseInCleartext -> {
                // If DNS supports only DoH and no clear text, we are forced to use it
                true
            }
            else -> {
                dns.isDnsOverHttps() && encryptDns
            }
        }
    }

    override fun toString(): String {
        return "(enabled=$tunnelEnabled, dns=${dns.id}, doh=$doh, gw=${gateway?.niceName()})"
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EngineConfiguration

        if (tunnelEnabled != other.tunnelEnabled) return false
        if (dns != other.dns) return false
        if (doh != other.doh) return false
        if (privateKey != other.privateKey) return false
        if (gateway != other.gateway) return false
        if (lease != other.lease) return false
        if (networkDns != other.networkDns) return false
        if (forceLibreMode != other.forceLibreMode) return false

        return true
    }

    override fun hashCode(): Int {
        var result = tunnelEnabled.hashCode()
        result = 31 * result + dns.hashCode()
        result = 31 * result + doh.hashCode()
        result = 31 * result + privateKey.hashCode()
        result = 31 * result + (gateway?.hashCode() ?: 0)
        result = 31 * result + (lease?.hashCode() ?: 0)
        result = 31 * result + networkDns.hashCode()
        result = 31 * result + forceLibreMode.hashCode()
        return result
    }

}

private data class EngineState(
    var tunnel: TunnelStatus = TunnelStatus.off(),
    var currentConfig: EngineConfiguration? = null,
    var onTunnelStatusChanged: (TunnelStatus) -> Unit = { _ -> },
    var restarting: Boolean = false,
) {

    @Synchronized fun inProgress() {
        tunnel = TunnelStatus.inProgress()
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun restarting() {
        restarting = true
        tunnel = TunnelStatus.inProgress()
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun libreMode(config: EngineConfiguration) {
        restarting = false
        tunnel = TunnelStatus.filteringOnly(config.dns, config.doh, config.gateway?.public_key)
        currentConfig = config
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun plusMode(config: EngineConfiguration) {
        restarting = false
        tunnel = TunnelStatus.connected(config.dns, config.doh, config.gateway())
        currentConfig = config
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun stopped(config: EngineConfiguration? = null) {
        tunnel = TunnelStatus.off()
        currentConfig = config
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun error(ex: Exception) {
        restarting = false
        tunnel = TunnelStatus.error(TunnelFailure(ex))
        onTunnelStatusChanged(tunnel)
    }

    @Synchronized fun isRestarting() = restarting
    @Synchronized fun isInProgress() = tunnel.inProgress

}