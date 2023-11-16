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

import binding.niceName
import channel.plusgateway.Gateway
import channel.pluslease.Lease
import com.wireguard.crypto.KeyPair
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import model.BlockaConfig
import model.BlokadaException
import model.Dns
import model.NetworkSpecificConfig
import model.PrivateKey
import model.PublicKey
import model.TunnelFailure
import model.TunnelStatus
import repository.DnsDataSource
import service.ConnectivityService
import service.VpnPermissionService
import ui.utils.cause
import utils.Logger
import java.net.InetAddress

object EngineService {

    private val log = Logger("Engine")
    private val vpnPerm = VpnPermissionService
    private val wgTunnel by lazy { WgTunnel }
    private val scope = GlobalScope

    private lateinit var config: EngineConfiguration
        @Synchronized set
        @Synchronized get

    private val state = EngineState()

    fun setup(network: NetworkSpecificConfig, user: BlockaConfig) {
        log.v("Engine initializing")
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
        log.v("Reloading engine, config: $config for ${config.network.network}, tun: ${config.tunnelEnabled}")

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
                !config.tunnelEnabled -> {
                    log.v("Marking engine stopped")
                    wgTunnel.stop()
                    state.stopped(config)
                }
                !vpnPerm.hasPermission() -> {
                    log.w("No VPN permissions, engine stopped")
                    state.stopped(config.copy(tunnelEnabled = false))
                }
                else -> {
                    log.v("Starting engine")
                    startAll(config)
                }
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
                // Plus mode for v6 (cloud filtering)
                isPlusMode()-> {
                    wgTunnel.start(config.privateKey, config.lease(), config.gateway())
                    state.plusMode(config)
                }
                else -> {
                    throw BlokadaException("Cannot start v6 in Libre mode")
                }
            }
        }
    }

    private suspend fun stopAll() {
        state.inProgress()
        wgTunnel.stop()
        log.w("Waiting after stopping system tunnel, before another start")
        delay(4000)
        state.stopped()
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

    fun newKeypair(): Pair<PrivateKey, PublicKey> {
        // Wireguard generated random keypair
        val keypair = KeyPair()
        val secret = keypair.privateKey.toBase64()
        val public = keypair.publicKey.toBase64()
        return secret to public
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

        private fun decideDoh(dns: Dns, plusMode: Boolean, encryptDns: Boolean): Boolean {
            // v6 does not support DoH
            return false
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

    private val scope = GlobalScope

    init {
        notifyListener()
    }

    @Synchronized fun inProgress() {
        tunnel = TunnelStatus.inProgress()
    }

    @Synchronized fun restarting() {
        restarting = true
        tunnel = TunnelStatus.inProgress()
        notifyListener()
    }

    @Synchronized fun plusMode(config: EngineConfiguration) {
        restarting = false
        tunnel = TunnelStatus.connected(config.dns, config.doh, config.gateway())
        currentConfig = config
        notifyListener()
    }

    @Synchronized fun stopped(config: EngineConfiguration? = null) {
        tunnel = TunnelStatus.off()
        currentConfig = config
        notifyListener()
    }

    @Synchronized fun error(ex: Exception) {
        restarting = false
        tunnel = TunnelStatus.error(TunnelFailure(ex))
        notifyListener()
    }

    @Synchronized fun isInProgress() = tunnel.inProgress

    private fun notifyListener() {
        scope.launch {
            onTunnelStatusChanged(tunnel)
        }
    }
}