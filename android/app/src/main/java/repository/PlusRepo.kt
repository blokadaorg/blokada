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

import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.asFlow
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch
import model.AccountType
import model.AppState
import model.BlockaConfig
import model.toAccountType
import service.*
import ui.MainApplication
import ui.TunnelViewModel
import utils.Logger


class PlusRepo {

    private val api by lazy { Services.apiForCurrentUser }
    private val persistence by lazy { PersistenceService }
    private val dialog by lazy { DialogService }
    private val env by lazy { EnvironmentService }
    private val context by lazy { ContextService }
    private val tunnelVM by lazy {
        val app = context.requireApp() as MainApplication
        ViewModelProvider(app).get(TunnelViewModel::class.java)
    }

    private val accountHot by lazy { Repos.account.accountHot }

    private val appRepo by lazy { Repos.app }
    private val processingRepo by lazy { Repos.processing }

//    private lazy var leaseRepo = Repos.leaseRepo
//    private lazy var gatewayRepo = Repos.gatewayRepo
//    private lazy var netxRepo = Repos.netxRepo

    private val writeBlockaConfig = MutableSharedFlow<BlockaConfig>(replay = 0)
    private val writePlusEnabled = MutableStateFlow<Boolean?>(null)

    val blockaConfig = writeBlockaConfig.filterNotNull()
    val plusEnabled = writePlusEnabled.filterNotNull()

//    private val newPlusT = Tasker<Gateway, Ignored>("newPlus")

    fun start() {
        onBlockaConfig_ExposeState()
        onTunnelStatus_UpdateProcessing()
        onAppPausedIndefinitely_StopPlusIfNecessary()
        onAppUnpaused_StartPlusIfNecessary()
        onAccountInactive_StopPlusIfNecessary()
    }

    // User engaged actions of turning Plus on and off are managed by
    // TunnelViewModel, here we only listen to those changes and
    // propagate the status to expose similar api like on ios.

    fun onBlockaConfig_ExposeState() {
        tunnelVM.config.observeForever {
            GlobalScope.launch {
                writeBlockaConfig.emit(it)
                writePlusEnabled.emit(it.vpnEnabled)
            }
        }
    }

    fun onTunnelStatus_UpdateProcessing() {
        tunnelVM.tunnelStatus.observeForever {
            GlobalScope.launch {
                processingRepo.notify("plusWorking", ongoing = it.inProgress)
            }
        }
    }


//    private func onChangePlusPause() {
//        changePlusPauseT.setTask { until in Just(until)
//            .flatMap { _ in self.netxRepo.changePause(until: until) }
//            .map { _ in true }
//            .eraseToAnyPublisher()
//        }
//    }
//
//    private func onCurrentLeaseGone_StopPlus() {
//        leaseRepo.currentHot
//            .filter { it in it.lease == nil }
//            .flatMap { _ in self.plusEnabledHot.first() }
//            .filter { plusEnabled in plusEnabled == true }
//            .flatMap { _ in self.accountHot.first() }
//            .sink(onValue: { it in
//                    self.switchPlusOff()
//                let msg = (it.account.isActive()) ?
//                L10n.errorVpnNoCurrentLeaseNew : L10n.errorVpnExpired
//
//                self.dialog.showAlert(
//                    message: msg,
//                    header: L10n.notificationVpnExpiredSubtitle
//                )
//                .sink()
//                    .store(in: &self.cancellables)
//            })
//        .store(in: &cancellables)
//    }

    // Untimed pause (appState Paused, but no pausedUntilHot value)
    private fun onAppPausedIndefinitely_StopPlusIfNecessary() {
        GlobalScope.launch {
            appRepo.appStateHot
            .filter { it == AppState.Paused }
            .collect {
                delay(500)
//            val paused = appRepo.pausedUntilHot.first()
//            if (paused == null) {
                // Do only if NETX is active
                val s = tunnelVM.tunnelStatus.asFlow().first { !it.inProgress }
                if (s.active /* || s.pauseSeconds > 0 */) {
                    // Just switch off Plus
                    tunnelVM.turnOff()
                }
//            }
            }
        }
    }

    // Simple restore Plus when app activated again and Plus was active before
    private fun onAppUnpaused_StartPlusIfNecessary() {
        GlobalScope.launch {
            appRepo.appStateHot
            .filter { it == AppState.Activated }
            .collect {
                delay(500)
                // Do only if NETX is inactive but was on
                val s = tunnelVM.tunnelStatus.asFlow().first { !it.inProgress }
                val vpnEnabled = tunnelVM.config.value?.vpnEnabled ?: false
                if (!s.active && vpnEnabled) {
                    // Just switch on Plus
                    tunnelVM.turnOn()
                }
            }
        }
    }

    private fun onAccountInactive_StopPlusIfNecessary() {
        GlobalScope.launch {
            accountHot
            .filter { it.type.toAccountType() != AccountType.Plus }
            .collect {
                val vpnEnabled = tunnelVM.config.value?.vpnEnabled ?: false
                if (vpnEnabled) {
                    Logger.w("Plus", "Turning off VPN because was active and account is not Plus anymore")
                    tunnelVM.turnOff(vpnEnabled = false)
                }
            }
        }
    }

//    // Timed pause
//    private func onAppPausedWithTimer_PausePlusIfNecessary() {
//        appRepo.pausedUntilHot
//            .compactMap { $0 }
//            .flatMap { until in Publishers.CombineLatest(
//                Just(until),
//                // Get NETX state once it settles
//                // TODO: this may introduce delay, not sure if it's safe
//                self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
//            ) }
//            // Do only if NETX is active
//            .filter { it in it.1.active || it.1.pauseSeconds > 0 }
//            // Make NETX pause (also will update "until" if changed)
//            .sink(onValue: { it in
//                    Logger.v("PlusRepo", "Pausing VPN as app is paused with timer")
//                self.changePlusPauseT.send(it.0)
//            })
//        .store(in: &cancellables)
//    }
//
//    private func onAppUnpaused_UnpausePlusIfNecessary() {
//        appRepo.pausedUntilHot
//            .filter { it in it == nil }
//            .flatMap { until in Publishers.CombineLatest(
//                Just(until),
//                // Get NETX state once it settles
//                // TODO: this may introduce delay, not sure if it's safe
//                self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
//            ) }
//            // Do only if NETX is paused
//            .filter { it in it.1.pauseSeconds > 0 }
//            // Make NETX unpause
//            .sink(onValue: { it in
//                    Logger.v("PlusRepo", "Unpausing VPN as app is unpaused")
//                self.changePlusPauseT.send(nil)
//            })
//        .store(in: &cancellables)
//    }

//    private suspend fun onAppActive_StartPlusIfNecessary() {
//        Publishers.CombineLatest(
//            appRepo.appStateHot,
//            leaseRepo.currentHot.removeDuplicates { a, b in a.lease != b.lease }
//        )
//            // If app got activated and current lease is there...
//            .filter { it in
//                    let (appState, currentLease) = it
//                return appState == .Activated && currentLease.lease != nil
//            }
//            .flatMap { _ in Publishers.CombineLatest(
//                self.plusEnabledHot.first(),
//                self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
//            ) }
//            // ... and while plus is enabled, but netx is not active...
//            .filter { it in
//                    let (plusEnabled, netxState) = it
//                return plusEnabled && !netxState.active
//            }
//            // ... start Plus
//            .sink(onValue: { it in
//                    Logger.v("PlusRepo", "Switch VPN on because app is active and Plus is enabled")
//                self.switchPlusOn()
//            })
//        .store(in: &cancellables)
//    }
//
}