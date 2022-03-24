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

import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.AccountType
import model.Granted
import org.blokada.R
import service.*
import ui.utils.AndroidUtils
import utils.Ignored
import utils.Logger

class PermsRepo {

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

    fun start() {
        GlobalScope.launch { onForeground_recheckPerms() }
        GlobalScope.launch { onDnsString_latest() }
        GlobalScope.launch { onAccountTypeUpgraded_showActivatedSheet() }
        GlobalScope.launch { onDnsProfileActivated_update() }
    }

    private suspend fun onForeground_recheckPerms() {
        enteredForegroundHot
        .combine(cloudRepo.dnsProfileActivatedHot) { _, activated -> activated }
        .collect { activated ->
            writeDnsProfilePerms.value = activated
            writeVpnProfilePerms.value = vpnPerms.hasPermission()
            writeNotificationPerms.value = notifications.hasPermissions()
            Logger.w("xxxxx", "Colecting: dns $activated, not: ${notifications.hasPermissions()}")
        }
    }

    private suspend fun onDnsProfileActivated_update() {
        cloudRepo.dnsProfileActivatedHot
        .collect { activated ->
            writeDnsProfilePerms.value = activated
            Logger.w("xxxxx", "Colecting: dns $activated")
        }
    }

    private suspend fun onDnsString_latest() {
        cloudRepo.expectedDnsStringHot.collect {
            writeDnsString.value = it
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

//    func maybeAskVpnProfilePerms() -> AnyPublisher<Granted, Error> {
//        return accountTypeHot.first()
//            .flatMap { it -> AnyPublisher<Granted, Error> in
//                    if it == .Plus {
//                        return self.vpnProfilePerms.first()
//                            .tryMap { granted -> Ignored in
//                                    if !granted {
//                                        throw "ask for vpn profile"
//                                    } else {
//                                        return true
//                                    }
//                            }
//                            .eraseToAnyPublisher()
//                    } else {
//                        return Just(true)
//                            .setFailureType(to: Error.self)
//                        .eraseToAnyPublisher()
//                    }
//            }
//            .tryCatch { _ in self.netxRepo.createVpnProfile() }
//            .eraseToAnyPublisher()
//    }

    suspend fun askForAllMissingPermissions() {
        delay(300)
        Logger.w("xxxx", "Before first dialog")
        maybeDisplayDnsProfilePermsDialog()
        delay(300)
        Logger.w("xxxx", "Before second dialog")
        maybeDisplayNotificationPermsDialog()
        Logger.w("xxxx", "After second dialog")
//        maybeDisplayNotificationPermsDialog()

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
            message = ctx.getString(R.string.dnsprofile_desc),
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

    // We want user to notice when they upgrade.
    // From Libre to Cloud or Plus, as well as from Cloud to Plus.
    // In the former case user will have to grant several permissions.
    // In the latter case, probably just the VPN perm.
    // If user is returning, it may be that he already has granted all perms.
    // But we display the Activated sheet anyway, as a way to show that upgrade went ok.
    // This will also trigger if StoreKit sends us transaction (on start) that upgrades.
    private suspend fun onAccountTypeUpgraded_showActivatedSheet() {
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