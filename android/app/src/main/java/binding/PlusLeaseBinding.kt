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
import channel.pluslease.Lease
import channel.pluslease.PlusLeaseOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import service.FlutterService

@Serializable
data class LegacyLease(
    val publicKey: String,
    val gatewayId: String,
    val alias: String?,
    val vip4: String,
    val vip6: String
) {

    companion object {
        fun fromLease(lease: Lease?): LegacyLease? {
            if (lease == null) return null
            return LegacyLease(
                publicKey = lease.publicKey,
                gatewayId = lease.gatewayId,
                alias = lease.alias,
                vip4 = lease.vip4,
                vip6 = lease.vip6
            )
        }
    }
}

object PlusLeaseBinding: PlusLeaseOps {
    val leases = MutableStateFlow<List<LegacyLease>>(emptyList())
    val currentLease = MutableStateFlow<LegacyLease?>(null)

    val leasesLive = MutableLiveData<List<LegacyLease>>()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val scope = GlobalScope

    init {
        PlusLeaseOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            leases.collect { leasesLive.postValue(it) }
        }
    }

    override fun doLeasesChanged(leases: List<Lease>, callback: (Result<Unit>) -> Unit) {
        this.leases.value = leases.map { LegacyLease.fromLease(it)!! }
        callback(Result.success(Unit))
    }

    override fun doCurrentLeaseChanged(lease: Lease?, callback: (Result<Unit>) -> Unit) {
        this.currentLease.value = LegacyLease.fromLease(lease)
        callback(Result.success(Unit))
    }
}