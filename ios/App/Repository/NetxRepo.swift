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
}

extension NetxConfig: Equatable {
    static func == (lhs: NetxConfig, rhs: NetxConfig) -> Bool {
        return
            lhs.lease == rhs.lease &&
            lhs.gateway == rhs.gateway
    }
}

// Tracks state of, and acts on the Network Extension.
class NetxRepo {

    var netxStateHot: AnyPublisher<NetworkStatus, Never> {
        writeNetxState.compactMap { $0 }.eraseToAnyPublisher()
    }

    fileprivate let writeNetxState = CurrentValueSubject<NetworkStatus?, Never>(nil)

    fileprivate let setConfigT = Tasker<NetxConfig, Ignored>("setConfigT")
    fileprivate let startVpnT = SimpleTasker<Ignored>("startVpn")
    fileprivate let stopVpnT = SimpleTasker<Ignored>("stopVpn")
    fileprivate let pauseVpnT = Tasker<Date, Ignored>("pauseVpn")
    fileprivate let createVpnProfileT = SimpleTasker<Ignored>("createVpnProfile")

    // Just for mocking?
    private var config: NetxConfig? = nil

    private let bgQueue = DispatchQueue(label: "NetxRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    init() {
        onSetConfig()
        onStartVpn()
        onStopVpn()
        onPauseVpn()
        readNetxStateOnStart()
    }

    func setConfig(_ lease: Lease, _ gateway: Gateway) -> AnyPublisher<Ignored, Error> {
        return setConfigT.send(NetxConfig(lease: lease, gateway: gateway))
    }

    func startVpn() -> AnyPublisher<Ignored, Error> {
        return startVpnT.send()
    }
    
    func stopVpn() -> AnyPublisher<Ignored, Error> {
        return stopVpnT.send()
    }

    func pauseVpn(until: Date) -> AnyPublisher<Ignored, Error> {
        return pauseVpnT.send(until)
    }

    func createVpnProfile() {
        
    }

    private func onSetConfig() {
        setConfigT.setTask { config in Just(config)
            .tryMap { it in self.config = it }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onStartVpn() {
        startVpnT.setTask { _ in Just(true)
            .delay(for: 3, scheduler: self.bgQueue)
            .map { _ in self.config?.gateway.public_key }
            .map { gatewayId in self.writeNetxState.send(NetworkStatus(
                active: true, inProgress: false,
                gatewayId: gatewayId, pauseSeconds: 0
            )) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onStopVpn() {
        stopVpnT.setTask { _ in Just(true)
            .delay(for: 2, scheduler: self.bgQueue)
            .map { _ in self.writeNetxState.send(NetworkStatus.disconnected()) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onPauseVpn() {
        pauseVpnT.setTask { _ in Just(true)
            .delay(for: 2, scheduler: self.bgQueue)
            .map { _ in self.writeNetxState.send(NetworkStatus(
                active: false, inProgress: false,
                gatewayId: nil, pauseSeconds: 300
            )) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func readNetxStateOnStart() {
        // TODO: tot
        writeNetxState.send(NetworkStatus.disconnected())
    }
}
