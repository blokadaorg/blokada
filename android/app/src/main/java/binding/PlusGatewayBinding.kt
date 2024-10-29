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
import channel.plusgateway.Gateway
import channel.plusgateway.PlusGatewayOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import service.FlutterService

@Serializable
data class LegacyGateway (
    val publicKey: String,
    val region: String,
    val location: String,
    val resourceUsagePercent: Long,
    val ipv4: String,
    val ipv6: String,
    val port: Long,
    val country: String? = null
) {
    fun niceName(): String {
        return location.split('-').map { it.capitalize() }.joinToString(" ")
    }

    companion object {
        fun fromGateway(gateway: Gateway?): LegacyGateway? {
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
    }
}

object PlusGatewayBinding: PlusGatewayOps {
    val gateways = MutableStateFlow<List<LegacyGateway>>(emptyList())
    val selected = MutableStateFlow<String?>(null)

    val gatewaysLive = MutableLiveData<List<LegacyGateway>>()

    private val flutter by lazy { FlutterService }
    private val scope = GlobalScope

    init {
        PlusGatewayOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            gateways.collect { gatewaysLive.postValue(it) }
        }
    }

    override fun doGatewaysChanged(gateways: List<Gateway>, callback: (Result<Unit>) -> Unit) {
        this.gateways.value = gateways.sortedBy { it.region + it.location }.map { LegacyGateway.fromGateway(it)!! }
        callback(Result.success(Unit))
    }

    override fun doSelectedGatewayChanged(publicKey: String?, callback: (Result<Unit>) -> Unit) {
        this.selected.value = publicKey
        callback(Result.success(Unit))
    }
}