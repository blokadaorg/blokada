//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

enum VpnStatus {
    case unknown
    case initializing
    case reconfiguring
    case deactivated
    case paused
    case activated
}

extension VpnStatus {
    func isReady() -> Bool {
        return self == .activated || self == .deactivated || self == .paused || self == .unknown
    }
}

class PlusVpnBinding: PlusVpnOps {
    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    private lazy var service = Services.netx

    private var status: VpnStatus = VpnStatus.unknown
    private var cancellables = Set<AnyCancellable>()

    init() {
        PlusVpnOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        _onNetxState()
    }

    func changePause(until: Date?) {
        
    }

    func doSetVpnConfig(config: VpnConfig, completion: @escaping (Result<Void, Error>) -> Void) {
        service.setConfig(config)
        .sink(
            onFailure: { err in completion(.failure(err)) },
            onSuccess: { completion(.success(())) }
        )
        .store(in: &cancellables)
    }

    func doSetVpnActive(active: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        if active {
            service.startVpn()
            .sink(
                onFailure: { err in completion(.failure(err)) },
                onSuccess: { completion(.success(())) }
            )
            .store(in: &cancellables)
        } else {
            service.stopVpn()
            .sink(
                onFailure: { err in completion(.failure(err)) },
                onSuccess: { completion(.success(())) }
            )
            .store(in: &cancellables)
        }
    }
    
    private func _onNetxState() {
        service.getStatePublisher()
        .sink(onValue: { it in
            self.status = it
            self.commands.execute(.vpnStatus, "\(it)")
        })
        .store(in: &cancellables)
    }
}

extension Container {
    var plusVpn: Factory<PlusVpnBinding> {
        self { PlusVpnBinding() }.singleton
    }
}
