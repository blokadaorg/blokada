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

protocol NetxServiceIn: Startable {

    func getStatePublisher() -> AnyPublisher<VpnStatus, Never>
    func getPermsPublisher() -> AnyPublisher<Granted, Never>
    func setConfig(_ config: VpnConfig) -> AnyPublisher<Ignored, Error>
    func startVpn() -> AnyPublisher<Ignored, Error>
    func stopVpn() -> AnyPublisher<Ignored, Error>
    func changePause(until: Date?) -> AnyPublisher<Ignored, Error>
    func createVpnProfile() -> AnyPublisher<Ignored, Error>
    func makeProtectedRequest(url: String, method: String, body: String) -> AnyPublisher<String, Error>
    func checkPerms()
    func refreshOnForeground()

}

class NetxServiceMock: NetxServiceIn {

    private var netxStateHot: AnyPublisher<VpnStatus, Never> {
        writeNetxState.compactMap { $0 }.eraseToAnyPublisher()
    }

    private var permsHot: AnyPublisher<Granted, Never> {
        writePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeNetxState = CurrentValueSubject<VpnStatus?, Never>(nil)
    fileprivate let writePerms = CurrentValueSubject<Granted?, Never>(nil)

    private var config: VpnConfig? = nil
    private var perms = false

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "NetxMockBgQueue")

    func start() {
        emitNoPermsOnStart()
    }

    func setConfig(_ config: VpnConfig) -> AnyPublisher<Ignored, Error> {
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    func startVpn() -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .delay(for: 3, scheduler: self.bgQueue)
        .map { _ in self.config?.gatewayPublicKey }
        .map { gatewayId in
            self.writeNetxState.send(.activated)
        }
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }
    
    func stopVpn() -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .delay(for: 2, scheduler: self.bgQueue)
        .map { _ in self.writeNetxState.send(.deactivated) }
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }
    
    func createVpnProfile() -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .delay(for: 3, scheduler: self.bgQueue)
        .map { _ in self.writePerms.send(true) }
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func makeProtectedRequest(url: String, method: String, body: String) -> AnyPublisher<String, Error> {
        return Fail(error: "No protected requests in mock").eraseToAnyPublisher()
    }

    func changePause(until: Date?) -> AnyPublisher<Ignored, Error> {
        return Just(true)
        .delay(for: 2, scheduler: self.bgQueue)
        .map { _ in self.writeNetxState.send(.deactivated) // TODO: pause
            
        }
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    func getStatePublisher() -> AnyPublisher<VpnStatus, Never> {
        return netxStateHot
    }

    func getPermsPublisher() -> AnyPublisher<Granted, Never> {
        return permsHot
    }

    func checkPerms() {
        
    }
    
    func refreshOnForeground() {}

    private func emitNoPermsOnStart() {
        self.writePerms.send(false)
        self.writeNetxState.send(.deactivated)
    }

}
