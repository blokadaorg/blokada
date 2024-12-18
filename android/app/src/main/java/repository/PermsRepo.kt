/*
 * This file is part of Blokada.
 *
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 *
 * Copyright © 2022 Blocka AB. All rights reserved.
 *
 * @author Karol Gusak (karol@blocka.net)
 */

package repository

import binding.AccountBinding
import binding.DeviceBinding
import binding.PermBinding
import binding.getType
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import model.AccountType
import model.Granted
import org.blokada.R
import service.ContextService
import service.DialogService
import service.NotificationService
import service.SystemNavService
import service.VpnPermissionService
import ui.utils.AndroidUtils

open class PermsRepo {

    private val writeNotificationPerms = MutableStateFlow<Granted?>(null)

    val notificationPermsHot = writeNotificationPerms.filterNotNull().distinctUntilChanged()

    private val context by lazy { ContextService }
    private val perm by lazy { PermBinding }
    private val vpnPerms by lazy { VpnPermissionService }
    private val device by lazy { DeviceBinding }
    private val account by lazy { AccountBinding }
    private val notification by lazy { NotificationService }

    private val dialog = DialogService
    private val systemNav = SystemNavService


    private var ongoingVpnPerm: CancellableContinuation<Granted>? = null
        @Synchronized set
        @Synchronized get

    open fun start() {
        onVpnPermsGranted_Proceed()
        GlobalScope.launch { writeNotificationPerms.emit(notification.hasPermissions()) }
    }

    private fun onVpnPermsGranted_Proceed() {
        // Also used in AskVpnProfileFragment, but that fragment is
        // not used in Cloud mode, so it won't collide
        vpnPerms.onPermissionGranted = { granted ->
//            GlobalScope.launch { writeNotificationPerms.emit(granted) }
            if (ongoingVpnPerm?.isCompleted == false) {
                ongoingVpnPerm?.resume(granted, {})
                ongoingVpnPerm = null
            }
        }
    }

    suspend fun maybeDisplayDnsProfilePermsDialog() {
        val granted = perm.dnsProfileActivated.value
        if (!granted) {
            displayDnsProfilePermsInstructions()
            .collect {

            }
        }
    }

    suspend fun maybeDisplayNotificationPermsDialog() {
        val granted = notificationPermsHot.first()
        if (!granted) {
            displayNotificationPermsInstructions()
            .collect {

            }
        }
    }

    suspend fun maybeAskVpnProfilePerms() {
        val type = account.account.value.getType()
        val granted = perm.vpnProfileActivated.value
        if (type == AccountType.Plus && !granted) {
            suspendCancellableCoroutine<Granted> { cont ->
                ongoingVpnPerm = cont
                vpnPerms.askPermission()
            }
        }
    }

    suspend fun askForAllMissingPermissions() {
        delay(300)
        maybeAskVpnProfilePerms()
        delay(300)
        maybeDisplayDnsProfilePermsDialog()
        delay(300)
        maybeDisplayNotificationPermsDialog()

//        return flowOf(true)
//        .debounce(300)
//        .combine(maybeDisplayDnsProfilePermsDialog()) { _, it -> it }
//        .combine(maybeDisplayNotificationPermsDialog()) { _, it -> it }
        // Show the activation sheet again to confirm user choices, and propagate error

//        return sheetRepo.dismiss()
//            .delay(for: 0.3, scheduler: self.bgQueue)
//        .flatMap { _ in self.notification.askForPermissions() }
//            .tryCatch { err in
//                    // Notification perm is optional, ask for others
//                    return Just(true)
//            }
//            .flatMap { _ in self.maybeAskVpnProfilePerms() }
//            .delay(for: 0.3, scheduler: self.bgQueue)
//        .flatMap { _ in self.maybeDisplayDnsProfilePermsDialog() }
//            .tryCatch { err -> AnyPublisher<Ignored, Error> in
//                    return Just(true)
//                        .delay(for: 0.3, scheduler: self.bgQueue)
//                .tryMap { _ -> Ignored in
//                        self.sheetRepo.showSheet(.Activated)
//                    throw err
//                }
//                    .eraseToAnyPublisher()
//            }
//            .eraseToAnyPublisher()
    }

    suspend fun displayNotificationPermsInstructions(): Flow<Boolean> {
        val ctx = context.requireContext()
        return dialog.showAlert(
            message = ctx.getString(R.string.notification_perms_denied),
            header = ctx.getString(R.string.notification_perms_header),
            okText = ctx.getString(R.string.dnsprofile_action_open_settings),
            okAction = {
                systemNav.openNotificationSettings()
            }
        )
    }

    suspend fun displayDnsProfilePermsInstructions(): Flow<Boolean> {
        val ctx = context.requireContext()
        return dialog.showAlert(
            message = "Copy your Blokada Cloud hostname to paste it in Settings.",
            header = ctx.getString(R.string.dnsprofile_header),
            okText = ctx.getString(R.string.universal_action_copy),
            okAction = {
                val expected = device.getExpectedDnsString()
                if (expected != null) {
                    AndroidUtils.copyToClipboard(expected)
                }
            }
        ).flatMapLatest {
            dialog.showAlert(
                message = "In the Settings app, find the Private DNS section, and then paste your hostname (long tap).",
                header = ctx.getString(R.string.dnsprofile_header),
                okText = ctx.getString(R.string.dnsprofile_action_open_settings),
                okAction = {
                    val expected = device.getExpectedDnsString()
                    if (expected != null) {
                        AndroidUtils.copyToClipboard(expected)
                    }
                    systemNav.openNetworkSettings()
                }
            )
        }
    }
}