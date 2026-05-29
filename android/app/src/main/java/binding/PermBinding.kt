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

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
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
    private const val BLOKADA_SIX_PACKAGE = "org.blokada.sex"
    private const val BLOKADA_SIX_OWNER = "blokada6"
    private const val NO_PROTECTION_OWNER = "none"

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

    override fun getPrivateDnsState(callback: (Result<PrivateDnsState>) -> Unit) {
        val current = connectivity.privateDns
        val state = PrivateDnsState(
            kind = if (current.isNullOrEmpty()) {
                PrivateDnsStateKind.DISABLED
            } else {
                PrivateDnsStateKind.ENABLED
            },
            serverUrl = current
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
        // TODO: actual perms?
        callback(Result.success(false))
    }

    override fun doVpnEnabled(callback: (Result<Boolean>) -> Unit) {
        val enabled = vpnPerms.hasPermission()
        vpnProfileActivated.value = enabled
        callback(Result.success(enabled))
    }

    override fun getParentDeviceProtectionOwner(callback: (Result<String>) -> Unit) {
        val ctx = context.requireContext()
        val sixInstalled =
            ctx.packageManager.getLaunchIntentForPackage(BLOKADA_SIX_PACKAGE) != null
        if (!sixInstalled) {
            callback(Result.success(NO_PROTECTION_OWNER))
            return
        }

        val owner = if (activeVpnLooksLikeBlokadaSix(ctx) || privateDnsLooksLikeBlokadaSix()) {
            BLOKADA_SIX_OWNER
        } else {
            NO_PROTECTION_OWNER
        }
        callback(Result.success(owner))
    }

    private fun activeVpnLooksLikeBlokadaSix(ctx: Context): Boolean {
        val manager = ctx.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val activeNetwork = manager.activeNetwork ?: return false
        val caps = manager.getNetworkCapabilities(activeNetwork) ?: return false
        if (!caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false

        val packages = ctx.packageManager.getPackagesForUid(caps.ownerUid) ?: return false
        return packages.contains(BLOKADA_SIX_PACKAGE)
    }

    private fun privateDnsLooksLikeBlokadaSix(): Boolean {
        val host = connectivity.privateDns ?: return false
        if (!host.endsWith(".cloud.blokada.org")) return false
        return host.removeSuffix(".cloud.blokada.org").contains("-")
    }

    override fun doOpenSettings(callback: (Result<Unit>) -> Unit) {
        val n = if (Flavor.isFamily()) FamilyOnboardingNotification() else OnboardingNotification();
        notification.show(n)
        val ctx = context.requireContext()
        val intent = intents.createNetworkSettingsIntent(ctx)
        intents.openIntentActivity(ctx, intent)
        callback(Result.success(Unit))
    }

    override fun doAskNotificationPerms(callback: (Result<Unit>) -> Unit) {
        scope.launch {
            permsRepo.maybeDisplayNotificationPermsDialog()
        }
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
