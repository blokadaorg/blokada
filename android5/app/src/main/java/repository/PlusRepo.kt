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
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch
import model.BlockaConfig
import service.*
import ui.MainApplication
import ui.TunnelViewModel


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
    private val deviceTagHot by lazy { Repos.cloud.deviceTagHot }

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
//    private func onCurrentLease_UpdateGatewaySelection() {
//        leaseRepo.currentHot
//            .sink(onValue: { it in
//                    // This will also set nil as gateway, in case of no current lease
//                    self.gatewayRepo.setGatewaySelection(it.lease?.gateway_id)
//            })
//        .store(in: &cancellables)
//    }
//
//    private func onCurrentLeaseAndGateway_UpdateNetx() {
//        // Emit only if lease and gateway are actually set
//        Publishers.CombineLatest4(
//            gatewayRepo.selectedHot.compactMap { it in it.gateway },
//            leaseRepo.currentHot.compactMap { it in it.lease },
//            accountHot.map { it in it.keypair.privateKey }.removeDuplicates(),
//            deviceTagHot
//        )
//            .sink(onValue: { it in
//                    let (gateway, lease, privateKey, deviceTag) = it
//                let config = NetxConfig(
//                        lease: lease, gateway: gateway,
//                deviceTag: deviceTag,
//                userAgent: self.env.userAgent(),
//                privateKey: privateKey
//                )
//                self.netxRepo.setConfig(config)
//            })
//        .store(in: &cancellables)
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
//
//    // Untimed pause (appState Paused, but no pausedUntilHot value)
//    private func onAppPausedIndefinitely_StopPlusIfNecessary() {
//        appRepo.appStateHot
//            .filter { it in it == .Paused }
//            .delay(for: 0.5, scheduler: bgQueue)
//            .flatMap { _ in self.appRepo.pausedUntilHot.first() }
//            .filter { it in it == nil }
//            .flatMap { _ in
//                    // Get NETX state once it settles
//                    self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
//            }
//            // Do only if NETX is active
//            .filter { it in it.active || it.pauseSeconds > 0 }
//            // Just switch off Plus
//            .sink(onValue: { it in
//                    Logger.v("PlusRepo", "Stopping VPN as app is paused undefinitely")
//                self.netxRepo.stopVpn()
//            })
//        .store(in: &cancellables)
//    }
//
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
//
//    private func onAppActive_StartPlusIfNecessary() {
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
//    private func onPlusEnabled_Persist() {
//        plusEnabledHot
//            .tryMap { it in self.savePlusEnabledToPers(it) }
//            .sink()
//            .store(in: &cancellables)
//    }
//
//    private func onNetxActuallyStarted_MarkPlusEnabled() {
//        netxRepo.netxStateHot.filter { !$0.inProgress }
//            .filter { $0.active }
//            .sink(onValue: { it in self.writePlusEnabled.send(true) })
//        .store(in: &cancellables)
//    }
//
//    private func loadPlusEnabledFromPersOnStart() {
//        persistence.getBool(forKey: "vpnEnabled")
//        .sink(
//            onValue: { it in
//                self.writePlusEnabled.send(it)
//        },
//        onFailure: { err in
//                Logger.e("PlusRepo", "Could not read vpnEnabled, ignoring: \(err)")
//            self.writePlusEnabled.send(false)
//        }
//        )
//        .store(in: &cancellables)
//    }
//
//    private func savePlusEnabledToPers(_ enabled: Bool) -> AnyPublisher<Ignored, Error> {
//        return persistence.setBool(enabled, forKey: "vpnEnabled")
//    }

}