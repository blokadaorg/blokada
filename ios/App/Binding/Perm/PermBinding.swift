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

class PermBinding: PermOps {

    // Whether DNS profile is currently selected or not, refreshed on foreground
    var dnsProfileActivatedHot: AnyPublisher<CloudDnsProfileActivated, Never> {
        self.writeDnsProfileActivated.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var vpnProfilePerms: AnyPublisher<Granted, Never> {
        writeVpnProfilePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    @Injected(\.flutter) private var flutter
    @Injected(\.env) private var env
    @Injected(\.notification) private var notification
    
    private lazy var privateDns = PrivateDnsService()
    private lazy var netx = Services.netx
    private lazy var permsRepo = Repos.permsRepo
    private lazy var systemNav = Services.systemNav

    fileprivate let writeDnsProfileActivated = CurrentValueSubject<CloudDnsProfileActivated?, Never>(nil)

    fileprivate let writeVpnProfilePerms = CurrentValueSubject<Granted, Never>(false)

    private var cancellables = Set<AnyCancellable>()

    init() {
        PermOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        onVpnPerms()
    }

    func doSetPrivateDnsEnabled(tag: String, alias: String, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDns.savePrivateDnsProfile(tag: tag, name: alias)
        .sink(
            onFailure: { err in completion(Result.failure(err))},
            onSuccess: { completion(Result.success(())) }
        )
        .store(in: &cancellables)
    }

    func doSetDns(tag: String, completion: @escaping (Result<Void, Error>) -> Void) {
        privateDns.savePrivateDnsProfile(tag: tag, name: nil)
        .sink(
            onFailure: { err in completion(Result.failure(err))},
            onSuccess: { completion(Result.success(())) }
        )
        .store(in: &cancellables)
    }

    func doNotificationEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        // TODO: actual perms?
        completion(.success(false))
    }
    
    func doVpnEnabled(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(.success(writeVpnProfilePerms.value))
    }

    func doOpenSettings(completion: @escaping (Result<Void, Error>) -> Void) {
        // Ask for notif perms oportunisticly (will help with onboarding)
        self.notification.askForPermissions()
            .receive(on: RunLoop.main)
            .sink(
                onFailure: { err in
                    self.openSystemSettings()
                    completion(Result.success(()))
                },
                onSuccess: {
                    self.openSystemSettings()
                    completion(Result.success(()))
                }
            )
            .store(in: &cancellables)
    }

    func getPrivateDnsSetting(completion: @escaping (Result<String, any Error>) -> Void) {
        privateDns.isPrivateDnsProfileActive()
        .combineLatest(privateDns.getPrivateDnsServerUrl())
        .sink(
            onValue: { (isActive, value) in
                if !isActive {
                    self.writeDnsProfileActivated.send(false)
                    return completion(Result.success(""))
                }
                self.writeDnsProfileActivated.send(true)
                return completion(Result.success(value))
            },
            onFailure: { err in
                self.writeDnsProfileActivated.send(false)
                completion(Result.failure(err))
            }
        )
        .store(in: &cancellables)
    }

    func openSystemSettings() {
        let id = self.flutter.isFlavorFamily ? NOTIF_ONBOARDING_FAMILY : NOTIF_ONBOARDING
        self.notification.scheduleNotification(id: id, when: Date().addingTimeInterval(3))
        self.systemNav.openSystemSettings()
    }

    private func onVpnPerms() {
        netx.getPermsPublisher()
        .sink(onValue: { it in
            self.writeVpnProfilePerms.send(it)
        })
        .store(in: &cancellables)
    }
}

extension Container {
    var perm: Factory<PermBinding> {
        self { PermBinding() }.singleton
    }
}
