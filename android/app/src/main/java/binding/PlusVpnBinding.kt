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

import channel.command.CommandName
import channel.pluslease.Lease
import channel.plusvpn.PlusVpnOps
import channel.plusvpn.VpnConfig
import engine.EngineService
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.BlockaConfig
import model.TunnelStatus
import service.FlutterService

fun VpnConfig.toLease(): Lease {
    // TODO: replace this old model
    return Lease(
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

object PlusVpnBinding: PlusVpnOps {
    private val flutter by lazy { FlutterService }
    private val engine by lazy { EngineService }
    private val command by lazy { CommandBinding }
    private val gateway by lazy { PlusGatewayBinding }

    val config = MutableStateFlow<Pair<VpnConfig?, Boolean>?>(null)
    val status = MutableStateFlow<TunnelStatus?>(null)
    private val scope = GlobalScope

    init {
        PlusVpnOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
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
                val gateway = gateway.gateways.value.firstOrNull { it.publicKey == vpn.gatewayPublicKey }
                val user = BlockaConfig(
                    privateKey = vpn.devicePrivateKey,
                    publicKey = "",
                    keysGeneratedForAccountId = "",
                    keysGeneratedForDevice = "",
                    lease = vpn.toLease(),
                    gateway = gateway,
                    vpnEnabled = active,
                    tunnelEnabled = active
                )
                engine.updateConfig(user = user)
            }
        }
    }

    override fun doSetVpnConfig(config: VpnConfig, callback: (Result<Unit>) -> Unit) {
        try {
            this.config.value =
                Pair(config, this.config.value?.second ?: false)
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
}