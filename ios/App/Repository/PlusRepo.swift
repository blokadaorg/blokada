//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

class PlusRepo: Startable {

    var plusEnabledHot: AnyPublisher<Bool, Never> {
        writePlusEnabled.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    private lazy var persistence = Services.persistenceLocal
    private lazy var dialog = Services.dialog
    private lazy var env = Services.env

    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var deviceTagHot = Repos.cloudRepo.deviceTagHot

    private lazy var leaseRepo = Repos.leaseRepo
    private lazy var gatewayRepo = Repos.gatewayRepo
    private lazy var netxRepo = Repos.netxRepo
    private lazy var appRepo = Repos.appRepo

    fileprivate let writePlusEnabled = CurrentValueSubject<Bool?, Never>(nil)

    fileprivate let newPlusT = Tasker<GatewayId, Ignored>("newPlus")
    fileprivate let clearPlusT = SimpleTasker<Ignored>("clearPlus")
    fileprivate let switchPlusOnT = SimpleTasker<Ignored>("switchPlusOn")
    fileprivate let switchPlusOffT = SimpleTasker<Ignored>("switchPlusOff")
    fileprivate let changePlusPauseT = Tasker<Date?, Ignored>("changePlusPause")

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "PlusRepoBgQueue")

    func start() {
        onNewPlus()
        onClearPlus()
        onSwitchPlusOn()
        onSwitchPlusOff()
        onChangePlusPause()
        onCurrentLease_UpdateGatewaySelection()
        onCurrentLeaseAndGateway_UpdateNetx()
        onCurrentLeaseGone_StopPlus()
        onAppPausedIndefinitely_StopPlusIfNecessary()
        onAppPausedWithTimer_PausePlusIfNecessary()
        onAppUnpaused_UnpausePlusIfNecessary()
        onAppActive_StartPlusIfNecessary()
        onPlusEnabled_Persist()
        onNetxActuallyStarted_MarkPlusEnabled()
        loadPlusEnabledFromPersOnStart()
    }

    // Create new config (location choice) and switch Plus on
    func newPlus(_ gw: GatewayId) -> AnyPublisher<Ignored, Error> {
        return newPlusT.send(gw)
    }
    
    // Switch Plus off, and clear all config
    func clearPlus() -> AnyPublisher<Ignored, Error> {
        return clearPlusT.send()
    }

    // Switch Plus back on to the last location choice
    func switchPlusOn() -> AnyPublisher<Ignored, Error> {
        return switchPlusOnT.send()
    }

    // Switch Plus off, but keep the config
    func switchPlusOff() -> AnyPublisher<Ignored, Error> {
        return switchPlusOffT.send()
    }

    private func onNewPlus() {
        newPlusT.setTask { gatewayId in Just(gatewayId)
            .flatMap { it in self.leaseRepo.newLease(it) }
            .flatMap { _ in self.switchPlusOn() }
            .tryCatch { err -> AnyPublisher<Ignored, Error> in
                // On error, show dialog to user and rethrow that error
                self.dialog.showAlert(
                    message: L10n.errorFetchingData
                )
                .tryMap { _ in throw err }
                .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
    }

    private func onClearPlus() {
        clearPlusT.setTask { _ in Just(true)
            .flatMap { _ in self.switchPlusOff() }
            .flatMap { _ in self.leaseRepo.currentHot.first() }
            .tryMap { it -> Lease in
                if let it = it.lease {
                    return it
                } else {
                    throw "plusRepo: no current lease"
                }
            }
            .flatMap { it in self.leaseRepo.deleteLease(it) }
            .eraseToAnyPublisher()
        }
    }

    private func onSwitchPlusOn() {
        switchPlusOnT.setTask { _ in Just(true)
            .map { _ in self.writePlusEnabled.send(true) }
            .flatMap { _ in self.netxRepo.startVpn() }
            .map { _ in self.leaseRepo.refreshLeases() }
            .map { _ in true }
            // On failure revert back the enabled switch
            .tryCatch { err -> AnyPublisher<Ignored, Error> in
                self.writePlusEnabled.send(false)
                throw err
            }
            .eraseToAnyPublisher()
        }
    }

    private func onSwitchPlusOff() {
        switchPlusOffT.setTask { _ in Just(true)
            .map { _ in self.writePlusEnabled.send(false) }
            .flatMap { _ in self.netxRepo.stopVpn() }
            .map { _ in true }
            // On failure revert back the enabled switch
            .tryCatch { err -> AnyPublisher<Ignored, Error> in
                self.writePlusEnabled.send(true)
                throw err
            }
            .eraseToAnyPublisher()
        }
    }

    private func onChangePlusPause() {
        changePlusPauseT.setTask { until in Just(until)
            .flatMap { _ in self.netxRepo.changePause(until: until) }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onCurrentLease_UpdateGatewaySelection() {
        leaseRepo.currentHot
        .sink(onValue: { it in
            // This will also set nil as gateway, in case of no current lease
            self.gatewayRepo.setGatewaySelection(it.lease?.gateway_id)
        })
        .store(in: &cancellables)
    }

    private func onCurrentLeaseAndGateway_UpdateNetx() {
        // Emit only if lease and gateway are actually set
        Publishers.CombineLatest4(
            gatewayRepo.selectedHot.compactMap { it in it.gateway },
            leaseRepo.currentHot.compactMap { it in it.lease },
            accountHot.map { it in it.keypair.privateKey }.removeDuplicates(),
            deviceTagHot
        )
        .sink(onValue: { it in
            let (gateway, lease, privateKey, deviceTag) = it
            let config = NetxConfig(
                lease: lease, gateway: gateway,
                deviceTag: deviceTag,
                userAgent: self.env.userAgent(),
                privateKey: privateKey
            )
            self.netxRepo.setConfig(config)
        })
        .store(in: &cancellables)
    }

    private func onCurrentLeaseGone_StopPlus() {
        leaseRepo.currentHot
        .filter { it in it.lease == nil }
        .flatMap { _ in self.plusEnabledHot.first() }
        .filter { plusEnabled in plusEnabled == true }
        .flatMap { _ in self.accountHot.first() }
        .sink(onValue: { it in
            self.switchPlusOff()
            let msg = (it.account.isActive()) ?
                L10n.errorVpnNoCurrentLeaseNew : L10n.errorVpnExpired

            self.dialog.showAlert(
                message: msg,
                header: L10n.notificationVpnExpiredSubtitle
            )
            .sink()
            .store(in: &self.cancellables)
        })
        .store(in: &cancellables)
    }

    // Untimed pause (appState Paused, but no pausedUntilHot value)
    private func onAppPausedIndefinitely_StopPlusIfNecessary() {
        appRepo.appStateHot
        .filter { it in it == .Paused || it == .Deactivated }
        .delay(for: 0.5, scheduler: bgQueue)
        .flatMap { _ in self.appRepo.pausedUntilHot.first() }
        .filter { it in it == nil }
        .flatMap { _ in
            // Get NETX state once it settles
            self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        }
        // Do only if NETX is active
        .filter { it in it.active || it.pauseSeconds > 0 }
        // Just switch off Plus
        .sink(onValue: { it in
            Logger.v("PlusRepo", "Stopping VPN as app is paused undefinitely")
            self.netxRepo.stopVpn()
        })
        .store(in: &cancellables)
    }

    // Timed pause
    private func onAppPausedWithTimer_PausePlusIfNecessary() {
        appRepo.pausedUntilHot
        .compactMap { $0 }
        .flatMap { until in Publishers.CombineLatest(
            Just(until),
            // Get NETX state once it settles
            // TODO: this may introduce delay, not sure if it's safe
            self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        ) }
        // Do only if NETX is active
        .filter { it in it.1.active || it.1.pauseSeconds > 0 }
        // Make NETX pause (also will update "until" if changed)
        .sink(onValue: { it in
            Logger.v("PlusRepo", "Pausing VPN as app is paused with timer")
            self.changePlusPauseT.send(it.0)
        })
        .store(in: &cancellables)
    }

    private func onAppUnpaused_UnpausePlusIfNecessary() {
        appRepo.pausedUntilHot
        .filter { it in it == nil }
        .flatMap { until in Publishers.CombineLatest(
            Just(until),
            // Get NETX state once it settles
            // TODO: this may introduce delay, not sure if it's safe
            self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        ) }
        // Do only if NETX is paused
        .filter { it in it.1.pauseSeconds > 0 }
        // Make NETX unpause
        .sink(onValue: { it in
            Logger.v("PlusRepo", "Unpausing VPN as app is unpaused")
            self.changePlusPauseT.send(nil)
        })
        .store(in: &cancellables)
    }

    private func onAppActive_StartPlusIfNecessary() {
        Publishers.CombineLatest(
            appRepo.appStateHot,
            leaseRepo.currentHot.removeDuplicates { a, b in a.lease != b.lease }
        )
        // If app got activated and current lease is there...
        .filter { it in
            let (appState, currentLease) = it
            return appState == .Activated && currentLease.lease != nil
        }
        .flatMap { _ in Publishers.CombineLatest(
            self.plusEnabledHot.first(),
            self.netxRepo.netxStateHot.filter { !$0.inProgress }.first()
        ) }
        // ... and while plus is enabled, but netx is not active...
        .filter { it in
            let (plusEnabled, netxState) = it
            return plusEnabled && !netxState.active
        }
        // ... start Plus
        .sink(onValue: { it in
            Logger.v("PlusRepo", "Switch VPN on because app is active and Plus is enabled")
            self.switchPlusOn()
        })
        .store(in: &cancellables)
    }

    private func onPlusEnabled_Persist() {
        plusEnabledHot
        .tryMap { it in self.savePlusEnabledToPers(it) }
        .sink()
        .store(in: &cancellables)
    }

    private func onNetxActuallyStarted_MarkPlusEnabled() {
        netxRepo.netxStateHot.filter { !$0.inProgress }
        .filter { $0.active }
        .sink(onValue: { it in self.writePlusEnabled.send(true) })
        .store(in: &cancellables)
    }

    private func loadPlusEnabledFromPersOnStart() {
        persistence.getBool(forKey: "vpnEnabled")
        .sink(
            onValue: { it in
                self.writePlusEnabled.send(it)
            },
            onFailure: { err in
                Logger.e("PlusRepo", "Could not read vpnEnabled, ignoring: \(err)")
                self.writePlusEnabled.send(false)
            }
        )
        .store(in: &cancellables)
    }

    private func savePlusEnabledToPers(_ enabled: Bool) -> AnyPublisher<Ignored, Error> {
        return persistence.setBool(enabled, forKey: "vpnEnabled")
    }

}
