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

import channel.perm.PermOps
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import repository.Repos
import service.ConnectivityService
import service.FlutterService
import service.VpnPermissionService

object PermBinding: PermOps {
    val dnsProfileActivated = MutableStateFlow(false)
    val vpnProfileActivated = MutableStateFlow(false)

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val permsRepo by lazy { Repos.perms }
    private val vpnPerms by lazy { VpnPermissionService }
    private val connectivity by lazy { ConnectivityService }
    private val device by lazy { DeviceBinding }
    private val scope = GlobalScope

    init {
        PermOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
        onPrivateDnsChanged()
    }

    private fun onPrivateDnsChanged() {
        connectivity.onPrivateDnsChanged = { privateDns ->
            val expected = device.getExpectedDnsString()
            dnsProfileActivated.value = privateDns == expected && expected != null
        }
        scope.launch {
            device.deviceTag.collect {
                val expected = device.getExpectedDnsString()
                dnsProfileActivated.value = connectivity.privateDns == expected && expected != null
            }
        }
    }

    override fun doPrivateDnsEnabled(tag: String, alias: String, callback: (Result<Boolean>) -> Unit) {
        callback(Result.success(dnsProfileActivated.value))
    }

    override fun doSetSetPrivateDnsEnabled(tag: String, alias: String, callback: (Result<Unit>) -> Unit) {
        // Cannot be done on Android
        callback(Result.success(Unit))
    }

    override fun doSetSetPrivateDnsForward(callback: (Result<Unit>) -> Unit) {
        TODO("Not yet implemented")
    }

    override fun doNotificationEnabled(callback: (Result<Boolean>) -> Unit) {
        // TODO: actual perms?
        callback(Result.success(false))
    }

    override fun doVpnEnabled(callback: (Result<Boolean>) -> Unit) {
        val enabled = vpnPerms.hasPermission()
        vpnProfileActivated.value = enabled
        callback(Result.success(enabled))
    }

}