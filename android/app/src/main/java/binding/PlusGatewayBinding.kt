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
import service.FlutterService

fun Gateway.niceName(): String {
    return location.split('-').map { it.capitalize() }.joinToString(" ")
}

object PlusGatewayBinding: PlusGatewayOps {
    val gateways = MutableStateFlow<List<Gateway>>(emptyList())
    val selected = MutableStateFlow<String?>(null)

    val gatewaysLive = MutableLiveData<List<Gateway>>()

    private val flutter by lazy { FlutterService }
    private val scope = GlobalScope

    init {
        PlusGatewayOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            gateways.collect { gatewaysLive.postValue(it) }
        }
    }

    override fun doGatewaysChanged(gateways: List<Gateway>, callback: (Result<Unit>) -> Unit) {
        this.gateways.value = gateways.sortedBy { it.region + it.location }
        callback(Result.success(Unit))
    }

    override fun doSelectedGatewayChanged(publicKey: String?, callback: (Result<Unit>) -> Unit) {
        this.selected.value = publicKey
        callback(Result.success(Unit))
    }
}