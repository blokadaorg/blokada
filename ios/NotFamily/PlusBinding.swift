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
import Flutter

extension OpsGateway {
    func niceName() -> String {
        return location.components(separatedBy: "-")
            .map { $0.capitalizingFirstLetter() }
            .joined(separator: " ")
    }
}

extension OpsGateway: Equatable {
    static func == (lhs: OpsGateway, rhs: OpsGateway) -> Bool {
        return
            lhs.publicKey == rhs.publicKey &&
            lhs.ipv4 == rhs.ipv4 &&
            lhs.ipv6 == rhs.ipv6 &&
            lhs.port == rhs.port
    }
}

struct GatewaySelection {
    let gateway: OpsGateway?
}

extension OpsLease {
    func activeUntil() -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = blockaDateFormat
        guard let date = dateFormatter.date(from: expires) else {
            dateFormatter.dateFormat = blockaDateFormatNoNanos
            guard let date = dateFormatter.date(from: expires) else {
                return Date(timeIntervalSince1970: 0)
            }
            return date
        }
        return date
    }

    func isActive() -> Bool {
        return activeUntil() > Date()
    }

    func niceName() -> String {
        return alias ?? String(publicKey.prefix(5))
    }
}

extension OpsLease: Equatable {
    static func == (lhs: OpsLease, rhs: OpsLease) -> Bool {
        return lhs.accountId == rhs.accountId
            && lhs.publicKey == rhs.publicKey
            && lhs.gatewayId == rhs.gatewayId
            && lhs.expires == rhs.expires
            && lhs.alias == rhs.alias
            && lhs.vip4 == rhs.vip4
            && lhs.vip6 == rhs.vip6
    }
}

// Used to do stuff before lease / account expires (and we may get net cutoff)
extension Date {
    func shortlyBefore() -> Date {
        let seconds = DateComponents(second: -10)
        return Calendar.current.date(byAdding: seconds, to: self) ?? self
    }
}

struct CurrentLease {
    let lease: OpsLease?
}

class PlusBinding: PlusOps {
    
    let plusEnabled = CurrentValueSubject<Bool, Never>(false)

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands
    
    let gateways = CurrentValueSubject<[OpsGateway], Never>([])
    let selected = CurrentValueSubject<GatewaySelection, Never>(
        GatewaySelection(gateway: nil)
    )
    
    let leases = CurrentValueSubject<[OpsLease], Never>([])
    let currentLease = CurrentValueSubject<CurrentLease, Never>(
        CurrentLease(lease: nil)
    )

    private lazy var service = Services.netx

    private var status: VpnStatus = VpnStatus.unknown
    private var cancellables = Set<AnyCancellable>()

    init() {
        PlusOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        _onNetxState()
    }

    func newPlus(_ gatewayPublicKey: String) {
        commands.execute(.newPlus, gatewayPublicKey)
    }

    func doPlusEnabledChanged(plusEnabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        self.plusEnabled.send(plusEnabled)
        completion(.success(()))
    }
    
    func doSelectedGatewayChanged(publicKey: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let gateway = gateways.value.first { it in
            it.publicKey == publicKey
        }
        selected.send(GatewaySelection(gateway: gateway))
        completion(.success(()))
    }

    func doGatewaysChanged(gateways: [OpsGateway], completion: @escaping (Result<Void, Error>) -> Void) {
        self.gateways.send(gateways)
        self.selected.send(self.selected.value)
        completion(.success(()))
    }

    func doLeasesChanged(leases: [OpsLease], completion: @escaping (Result<Void, Error>) -> Void) {
        self.leases.send(leases)
        completion(.success(()))
    }

    func doCurrentLeaseChanged(lease: OpsLease?, completion: @escaping (Result<Void, Error>) -> Void) {
        currentLease.send(CurrentLease(lease: lease))
        completion(.success(()))
    }
    
    func changePause(until: Date?) {
        
    }

    func doSetVpnConfig(config: OpsVpnConfig, completion: @escaping (Result<Void, Error>) -> Void) {
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

    func doGenerateKeypair(completion: @escaping (Result<OpsKeypair, any Error>) -> Void) {
        let privKey = PrivateKey()
        let pubKey = privKey.publicKey
        let currentKeypair = OpsKeypair(
            publicKey: pubKey.base64Key,
            privateKey: privKey.base64Key
        )
        completion(.success(currentKeypair))
    }

    func doGetInstalledApps(completion: @escaping (Result<[OpsInstalledApp], any Error>) -> Void) {
        completion(.failure("doGetInstalledApps is Android only"))
    }
    
    func doGetAppIcon(packageName: String, completion: @escaping (Result<FlutterStandardTypedData?, any Error>) -> Void) {
        completion(.failure("doGetAppIcon is Android only"))
    }
}

extension Container {
    var plus: Factory<PlusBinding> {
        self { PlusBinding() }.singleton
    }
}
