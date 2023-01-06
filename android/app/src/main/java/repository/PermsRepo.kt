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

import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import model.AccountType
import model.Granted
import org.blokada.R
import service.*
import ui.utils.AndroidUtils
import utils.Ignored
import utils.Logger

open class PermsRepo {

    private val writeDnsProfilePerms = MutableStateFlow<Granted?>(null)
    private val writeVpnProfilePerms = MutableStateFlow<Granted?>(null)
    private val writeNotificationPerms = MutableStateFlow<Granted?>(null)

    private val writeDnsString = MutableStateFlow<String?>(null)

    val dnsProfilePermsHot = writeDnsProfilePerms.filterNotNull().distinctUntilChanged()
    val vpnProfilePermsHot = writeVpnProfilePerms.filterNotNull().distinctUntilChanged()
    val notificationPermsHot = writeNotificationPerms.filterNotNull().distinctUntilChanged()

    private val enteredForegroundHot = Repos.stage.enteredForegroundHot
    private val accountTypeHot = Repos.account.accountTypeHot

    private val context = ContextService
    private val dialog = DialogService
    private val systemNav = SystemNavService
    private val vpnPerms = VpnPermissionService
    private val notifications = NotificationService

    private val cloudRepo = Repos.cloud

    private var previousAccountType: AccountType? = null

    private var ongoingVpnPerm: CancellableContinuation<Granted>? = null
        @Synchronized set
        @Synchronized get

    open fun start() {
        onForeground_recheckPerms()
        onDnsString_latest()
        onAccountTypeUpgraded_showActivatedSheet()
        onDnsProfileActivated_update()
        onVpnPermsGranted_Proceed()
    }

    private fun onForeground_recheckPerms() {
        GlobalScope.launch {
            enteredForegroundHot
            .combine(cloudRepo.dnsProfileActivatedHot) { _, activated -> activated }
            .collect { activated ->
                Logger.v("Perms", "DNS profile: $activated, notifications: ${notifications.hasPermissions()}")
                writeDnsProfilePerms.value = activated
                writeVpnProfilePerms.value = vpnPerms.hasPermission()
                writeNotificationPerms.value = notifications.hasPermissions()
            }
        }
    }

    private fun onDnsProfileActivated_update() {
        GlobalScope.launch {
            cloudRepo.dnsProfileActivatedHot
            .collect { activated ->
                Logger.v("Perms", "DNS profile: $activated")
                writeDnsProfilePerms.value = activated
            }
        }
    }

    private fun onDnsString_latest() {
        GlobalScope.launch {
            cloudRepo.expectedDnsStringHot.collect {
                writeDnsString.value = it
            }
        }
    }

    private fun onVpnPermsGranted_Proceed() {
        // Also used in AskVpnProfileFragment, but that fragment is
        // not used in Cloud mode, so it won't collide
        vpnPerms.onPermissionGranted = { granted ->
            GlobalScope.launch { writeNotificationPerms.emit(granted) }
            if (ongoingVpnPerm?.isCompleted == false) {
                ongoingVpnPerm?.resume(granted, {})
                ongoingVpnPerm = null
            }
        }
    }

    suspend fun maybeDisplayDnsProfilePermsDialog() {
        val granted = dnsProfilePermsHot.first()
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
        val type = accountTypeHot.first()
        val granted = vpnProfilePermsHot.first()
        if (type == AccountType.Plus && !granted) {
            suspendCancellableCoroutine<Granted> { cont ->
                ongoingVpnPerm = cont
                vpnPerms.askPermission()
            }
        }
    }

    suspend fun askForAllMissingPermissions() {
        delay(300)
        maybeDisplayDnsProfilePermsDialog()
        delay(300)
        maybeDisplayNotificationPermsDialog()
        delay(300)
        maybeAskVpnProfilePerms()

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

    suspend fun displayNotificationPermsInstructions(): Flow<Ignored> {
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

    suspend fun displayDnsProfilePermsInstructions(): Flow<Ignored> {
        val ctx = context.requireContext()
        return dialog.showAlert(
            message = "Copy your Blokada Cloud hostname to paste it in Settings.",
            header = ctx.getString(R.string.dnsprofile_header),
            okText = ctx.getString(R.string.universal_action_copy),
            okAction = {
                writeDnsString.value?.run {
                    AndroidUtils.copyToClipboard(this)
                }
            }
        ).flatMapLatest {
            dialog.showAlert(
                message = "In the Settings app, find the Private DNS section, and then paste your hostname (long tap).",
                header = ctx.getString(R.string.dnsprofile_header),
                okText = ctx.getString(R.string.dnsprofile_action_open_settings),
                okAction = {
                    writeDnsString.value?.run {
                        AndroidUtils.copyToClipboard(this)
                        systemNav.openNetworkSettings()
                    }
                }
            )
        }
    }

    // We want user to notice when they upgrade.
    // From Libre to Cloud or Plus, as well as from Cloud to Plus.
    // In the former case user will have to grant several permissions.
    // In the latter case, probably just the VPN perm.
    // If user is returning, it may be that he already has granted all perms.
    // But we display the Activated sheet anyway, as a way to show that upgrade went ok.
    // This will also trigger if StoreKit sends us transaction (on start) that upgrades.
    private fun onAccountTypeUpgraded_showActivatedSheet() {
        GlobalScope.launch {
            accountTypeHot
            .filter { now ->
                if (previousAccountType == null) {
                    previousAccountType = now
                    false
                } else {
                    val prev = previousAccountType
                    previousAccountType = now

                    if (prev == AccountType.Libre && now != AccountType.Libre) {
                        true
                    } else prev == AccountType.Cloud && now == AccountType.Plus
                }
            }
            .collect {
//            .sink(onValue: { _ in self.sheetRepo.showSheet(.Activated)} )
            }
        }
    }
}

class DebugPermsRepo: PermsRepo() {

    override fun start() {
        super.start()

        GlobalScope.launch {
            dnsProfilePermsHot.collect {
                Logger.e("PermsRepo", "Private DNS perms now: $it")
            }
        }
    }

}