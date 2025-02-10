/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2023 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package binding

import androidx.lifecycle.MutableLiveData
import channel.command.CommandName
import channel.plus.OpsGateway
import channel.plus.OpsKeypair
import channel.plus.OpsLease
import channel.plus.OpsVpnConfig
import channel.plus.PlusOps
import engine.EngineService
import engine.KeypairService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.BlockaConfig
import model.LegacyGateway
import model.LegacyLease
import model.TunnelStatus
import service.EnvironmentService
import service.FlutterService

fun OpsVpnConfig.toLease(): OpsLease {
    // TODO: replace this old model
    return OpsLease(
        accountId = "",
        publicKey = "",
        gatewayId = gatewayPublicKey,
        expires = "",
        alias = gatewayNiceName,
        vip4 = leaseVip4,
        vip6 = leaseVip6
    )
}

fun TunnelStatus.toVpnStatus(): String {
    return when {
        inProgress || restarting -> "reconfiguring"
        active -> "activated"
        else -> "deactivated"
    }
}

object PlusBinding: PlusOps {
    private val flutter by lazy { FlutterService }
    private val engine by lazy { EngineService }
    private val keypair by lazy { KeypairService }
    private val command by lazy { CommandBinding }

    val config = MutableStateFlow<Pair<OpsVpnConfig?, Boolean>?>(null)
    val status = MutableStateFlow<TunnelStatus?>(null)
    private val scope = GlobalScope

    init {
        // Vpn
        PlusOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        engine.setOnTunnelStatusChangedListener {
            scope.launch {
                status.value = it
                command.execute(CommandName.VPNSTATUS, it.toVpnStatus())
            }
        }
        scope.launch {
            config.filterNotNull().collect {
                val (vpn, active) = it
                if (vpn == null) return@collect
                val gateway = gateways.value.firstOrNull { it.publicKey == vpn.gatewayPublicKey }
                val user = BlockaConfig(
                    privateKey = vpn.devicePrivateKey,
                    publicKey = "",
                    keysGeneratedForAccountId = "",
                    keysGeneratedForDevice = "",
                    lease = fromLease(vpn.toLease()),
                    gateway = gateway,
                    vpnEnabled = active,
                    tunnelEnabled = active
                )
                engine.updateConfig(user = user)
            }
        }

        // Gateway
        scope.launch {
            gateways.collect { gatewaysLive.postValue(it) }
        }

        // Lease
        scope.launch {
            leases.collect { leasesLive.postValue(it) }
        }
    }

    override fun doSetVpnConfig(config: OpsVpnConfig, callback: (Result<Unit>) -> Unit) {
        try {
            this.config.value =
                Pair(config, this.config.value?.second ?: false)
            EnvironmentService.deviceTag = config.deviceTag
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    override fun doSetVpnActive(active: Boolean, callback: (Result<Unit>) -> Unit) {
        try {
            val cfg = this.config.value
            this.config.value = Pair(cfg?.first, active)
            callback(Result.success(Unit))
        } catch (e: Exception) {
            callback(Result.failure(e))
        }
    }

    // Gateway

    val gateways = MutableStateFlow<List<LegacyGateway>>(emptyList())
    val selected = MutableStateFlow<String?>(null)

    val gatewaysLive = MutableLiveData<List<LegacyGateway>>()

    override fun doGatewaysChanged(gateways: List<OpsGateway>, callback: (Result<Unit>) -> Unit) {
        this.gateways.value = gateways.sortedBy { it.region + it.location }.map { fromGateway(it)!! }
        callback(Result.success(Unit))
    }

    override fun doSelectedGatewayChanged(publicKey: String?, callback: (Result<Unit>) -> Unit) {
        this.selected.value = publicKey
        callback(Result.success(Unit))
    }

    // Lease

    val leases = MutableStateFlow<List<LegacyLease>>(emptyList())
    val currentLease = MutableStateFlow<LegacyLease?>(null)
    val leasesLive = MutableLiveData<List<LegacyLease>>()

    override fun doLeasesChanged(leases: List<OpsLease>, callback: (Result<Unit>) -> Unit) {
        this.leases.value = leases.map { fromLease(it)!! }
        callback(Result.success(Unit))
    }

    override fun doCurrentLeaseChanged(lease: OpsLease?, callback: (Result<Unit>) -> Unit) {
        this.currentLease.value = fromLease(lease)
        callback(Result.success(Unit))
    }

    // Keypair

    override fun doGenerateKeypair(callback: (Result<OpsKeypair>) -> Unit) {
        val keypair = keypair.newKeypair()
        val converted = OpsKeypair(
            publicKey = keypair.second,
            privateKey = keypair.first,
        )
        callback(Result.success(converted))
    }

    // Plus

    val plusEnabled = MutableStateFlow(false)

    fun newPlus(gatewayPublicKey: String) {
        scope.launch {
            command.execute(CommandName.NEWPLUS, gatewayPublicKey)
        }
    }

    override fun doPlusEnabledChanged(plusEnabled: Boolean, callback: (Result<Unit>) -> Unit) {
        this.plusEnabled.value = plusEnabled
        callback(Result.success(Unit))
    }
}

// Gateway
fun fromGateway(gateway: OpsGateway?): LegacyGateway? {
    if (gateway == null) return null
    return LegacyGateway(
        publicKey = gateway.publicKey,
        region = gateway.region,
        location = gateway.location,
        resourceUsagePercent = gateway.resourceUsagePercent,
        ipv4 = gateway.ipv4,
        ipv6 = gateway.ipv6,
        port = gateway.port,
        country = gateway.country
    )
}

// Lease
fun fromLease(lease: OpsLease?): LegacyLease? {
    if (lease == null) return null
    return LegacyLease(
        publicKey = lease.publicKey,
        gatewayId = lease.gatewayId,
        alias = lease.alias,
        vip4 = lease.vip4,
        vip6 = lease.vip6
    )
}

