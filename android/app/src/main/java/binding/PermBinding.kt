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
import channel.perm.PrivateDnsState
import channel.perm.PrivateDnsStateKind
import kotlinx.coroutines.CoroutineScope
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
import utils.cause
import utils.FamilyOnboardingNotification
import utils.Intents
import utils.Logger
import utils.OnboardingNotification


object PermBinding : PermOps {
    val vpnProfileActivated = MutableStateFlow(false)

    private val flutter by lazy { FlutterService }
    private val notification by lazy { NotificationService }
    private val permsRepo by lazy { Repos.perms }
    private val vpnPerms by lazy { VpnPermissionService }
    private val connectivity by lazy { ConnectivityService }
    private val context by lazy { ContextService }
    private val intents by lazy { Intents }
    private val scope = CoroutineScope(Dispatchers.Main)
    private val biometric by lazy { BiometricService }

    init {
        PermOps.setUp(flutter.engine.dartExecutor.binaryMessenger, this)
    }

    // Reads live, not the callback cache: on resume from Settings the cache
    // can still hold the old value, which kept the setup sheet open.
    override fun getPrivateDnsState(callback: (Result<PrivateDnsState>) -> Unit) {
        val current = try {
            connectivity.readPrivateDns()
        } catch (ex: Exception) {
            Logger.e("PermBinding", "Could not read Private DNS".cause(ex))
            callback(Result.failure(ex))
            return
        }
        val state = PrivateDnsState(
            kind = if (current.hostname.isNullOrEmpty()) {
                PrivateDnsStateKind.DISABLED
            } else {
                PrivateDnsStateKind.ENABLED
            },
            serverUrl = current.hostname,
            privateDnsBroken = current.broken
        )
        callback(Result.success(state))
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
        callback(Result.success(notification.hasPermissions()))
    }

    override fun doVpnEnabled(callback: (Result<Boolean>) -> Unit) {
        val enabled = vpnPerms.hasPermission()
        vpnProfileActivated.value = enabled
        callback(Result.success(enabled))
    }

    override fun doOpenSettings(callback: (Result<Unit>) -> Unit) {
        val n = if (Flavor.isFamily()) FamilyOnboardingNotification() else OnboardingNotification();
        notification.show(n)
        val ctx = context.requireContext()
        val intent = intents.createNetworkSettingsIntent(ctx)
        intents.openIntentActivity(ctx, intent)
        callback(Result.success(Unit))
    }

    /**
     * Best effort: Dart awaits this before continuing flows such as Safari
     * activation, so it always completes, even if the ask itself fails.
     */
    override fun doAskNotificationPerms(callback: (Result<Unit>) -> Unit) {
        try {
            permsRepo.maybeDisplayNotificationPermsDialog()
        } catch (ex: Exception) {
            Logger.e("PermBinding", "Could not ask for notification permission".cause(ex))
        }
        callback(Result.success(Unit))
    }

    override fun doAskVpnPerms(callback: (Result<Unit>) -> Unit) {
        vpnPerms.askPermission()
        callback(Result.success(Unit))
    }

    override fun doAuthenticate(callback: (Result<Boolean>) -> Unit) {
        scope.launch {
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

    override fun isRunningOnMac(callback: (Result<Boolean>) -> Unit) {
        // Android apps cannot run on Mac, always return false
        callback(Result.success(false))
    }
}
