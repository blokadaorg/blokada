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
import channel.pluslease.Lease
import channel.pluslease.PlusLeaseOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import service.FlutterService

fun Lease.niceName(): String {
    return if (alias?.isNotBlank() == true) alias else publicKey.take(5)
}

//fun Lease.isActive() = expires > Date()

object PlusLeaseBinding: PlusLeaseOps {
    val leases = MutableStateFlow<List<Lease>>(emptyList())
    val currentLease = MutableStateFlow<Lease?>(null)

    val leasesLive = MutableLiveData<List<Lease>>()

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val scope = GlobalScope

    init {
        PlusLeaseOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        scope.launch {
            leases.collect { leasesLive.postValue(it) }
        }
    }

    fun deleteLease(lease: Lease) {
        scope.launch {
            command.execute(CommandName.DELETELEASE, lease.publicKey)
        }
    }

    override fun doLeasesChanged(leases: List<Lease>, callback: (Result<Unit>) -> Unit) {
        this.leases.value = leases
        callback(Result.success(Unit))
    }

    override fun doCurrentLeaseChanged(lease: Lease?, callback: (Result<Unit>) -> Unit) {
        this.currentLease.value = lease
        callback(Result.success(Unit))
    }
}