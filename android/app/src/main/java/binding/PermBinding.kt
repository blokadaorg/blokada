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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import repository.Repos
import service.BiometricService
import service.ConnectivityService
import service.ContextService
import service.Flavor
import service.FlutterService
import service.NotificationService
import service.SystemNavService
import service.VpnPermissionService
import ui.utils.cause
import utils.FamilyOnboardingNotification
import utils.Logger
import utils.OnboardingNotification


object PermBinding: PermOps {
    val dnsProfileActivated = MutableStateFlow(false)
    val vpnProfileActivated = MutableStateFlow(false)

    private val flutter by lazy { FlutterService }
    private val command by lazy { CommandBinding }
    private val notification by lazy { NotificationService }
    private val permsRepo by lazy { Repos.perms }
    private val vpnPerms by lazy { VpnPermissionService }
    private val connectivity by lazy { ConnectivityService }
    private val device by lazy { DeviceBinding }
    private val context by lazy { ContextService }
    private val systemNav by lazy { SystemNavService }
    private val scope = GlobalScope
    private val biometric by lazy { BiometricService }

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

    override fun getPrivateDnsSetting(callback: (Result<String>) -> Unit) {
        callback(Result.success(connectivity.privateDns ?: ""))
    }

    override fun doSetPrivateDnsEnabled(
        tag: String,
        alias: String,
        callback: (Result<Unit>) -> Unit
    ) {
        // Cannot be done on Android
        callback(Result.success(Unit))
    }

    override fun doSetDns(tag: String, callback: (Result<Unit>) -> Unit) {
        // Cannot be done on Android
        callback(Result.success(Unit))
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

    override fun doOpenSettings(callback: (Result<Unit>) -> Unit) {
        val n = if (Flavor.isFamily()) FamilyOnboardingNotification() else OnboardingNotification();
        notification.show(n);
        systemNav.openNetworkSettings()
        callback(Result.success(Unit))
    }

    override fun doAskNotificationPerms(callback: (Result<Unit>) -> Unit) {
        GlobalScope.launch {
            permsRepo.maybeDisplayNotificationPermsDialog()
        }
    }

    override fun doAskVpnPerms(callback: (Result<Unit>) -> Unit) {
        vpnPerms.askPermission()
        callback(Result.success(Unit))
    }

    override fun doAuthenticate(callback: (Result<Boolean>) -> Unit) {
        scope.launch(Dispatchers.Main) {
            if (biometric.isBiometricReady(context.requireContext())) {
                try {
                    biometric.auth(context.requireFragment()) // Will throw on bad auth
                } catch (ex: Exception) {
                    Logger.e("SettingsAccount", "Could not authenticate".cause(ex));
                    callback(Result.success(false))
                    return@launch
                }
            }

            callback(Result.success(true))
        }
    }

}