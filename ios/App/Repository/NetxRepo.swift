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

struct NetxConfig {
    let lease: Lease
    let gateway: Gateway
    let deviceTag: String
    let userAgent: String
    let privateKey: String
}

extension NetxConfig: Equatable {
    static func == (lhs: NetxConfig, rhs: NetxConfig) -> Bool {
        return
            lhs.lease == rhs.lease &&
            lhs.gateway == rhs.gateway
    }
}

// Tracks state of, and acts on the Network Extension.
class NetxRepo: Startable {

    var netxStateHot: AnyPublisher<NetworkStatus, Never> {
        writeNetxState.compactMap { $0 }.eraseToAnyPublisher()
    }

    var permsHot: AnyPublisher<Granted, Never> {
        writePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    private lazy var service = Services.netx

    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot

    fileprivate let writeNetxState = CurrentValueSubject<NetworkStatus?, Never>(nil)
    fileprivate let writePerms = CurrentValueSubject<Granted?, Never>(nil)

    fileprivate let setConfigT = Tasker<NetxConfig, Ignored>("setConfigT")
    fileprivate let startVpnT = SimpleTasker<Ignored>("startVpn")
    fileprivate let stopVpnT = SimpleTasker<Ignored>("stopVpn")
    fileprivate let changeVpnPauseT = Tasker<Date?, Ignored>("changeVpnPause")
    fileprivate let createVpnProfileT = SimpleTasker<Ignored>("createVpnProfile")

    private var cancellables = Set<AnyCancellable>()

    func start() {
        onSetConfig()
        onStartVpn()
        onStopVpn()
        onPauseVpn()
        onCreateVpnProfile()
        onForeground_CheckPerms()
        onNetxState_PropagateFromService()
        onNetxPerms_PropagateFromService()
    }

    func setConfig(_ config: NetxConfig) -> AnyPublisher<Ignored, Error> {
        return setConfigT.send(config)
    }

    func startVpn() -> AnyPublisher<Ignored, Error> {
        return startVpnT.send()
    }

    func stopVpn() -> AnyPublisher<Ignored, Error> {
        return stopVpnT.send()
    }

    func changePause(until: Date?) -> AnyPublisher<Ignored, Error> {
        return changeVpnPauseT.send(until)
    }

    func createVpnProfile() -> AnyPublisher<Ignored, Error> {
        return createVpnProfileT.send()
    }

    private func onSetConfig() {
        setConfigT.setTask { config in
            self.service.setConfig(config)
        }
    }

    private func onStartVpn() {
        startVpnT.setTask { _ in
            self.service.startVpn()
        }
    }

    private func onStopVpn() {
        stopVpnT.setTask { _ in
            self.service.stopVpn()
        }
    }

    private func onPauseVpn() {
        changeVpnPauseT.setTask { until in
            self.service.changePause(until: until)
        }
    }

    private func onCreateVpnProfile() {
        createVpnProfileT.setTask { _ in
            self.service.createVpnProfile()
        }
    }

    private func onForeground_CheckPerms() {
        enteredForegroundHot
        .sink(onValue: { _ in self.service.checkPerms() })
        .store(in: &cancellables)
    }

    private func onNetxState_PropagateFromService() {
        service.getStatePublisher()
        .sink(onValue: { it in self.writeNetxState.send(it) })
        .store(in: &cancellables)
    }

    private func onNetxPerms_PropagateFromService() {
        service.getPermsPublisher()
        .sink(onValue: { it in self.writePerms.send(it) })
        .store(in: &cancellables)
    }

}

class DebugNetxRepo: NetxRepo {

    private let log = BlockaLogger("Netx")
    private var cancellables = Set<AnyCancellable>()

    override func start() {
        super.start()

        writeNetxState.sink(
            onValue: { it in
                self.log.v("Netx state: \(it)")
            }
        )
        .store(in: &cancellables)
    }

}
