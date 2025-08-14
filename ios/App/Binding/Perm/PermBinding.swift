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
import UIKit

class PermBinding: PermOps {

    var vpnProfilePerms: AnyPublisher<Granted, Never> {
        writeVpnProfilePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    @Injected(\.flutter) private var flutter
    @Injected(\.common) private var notification
    
    private lazy var privateDns = Services.privateDns
    private lazy var netx = Services.netx
    private lazy var permsRepo = Repos.permsRepo
    private lazy var systemNav = Services.systemNav
    private lazy var account = ViewModels.account

    fileprivate let writeVpnProfilePerms = CurrentValueSubject<Granted?, Never>(nil)

    private var cancellables = Set<AnyCancellable>()

    init() {
        PermOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        onVpnPerms()
    }
    
    func doAuthenticate(completion: @escaping (Result<Bool, any Error>) -> Void) {
        account.authenticate(ok: { _ in
            completion(.success(true))
        }, fail: { _ in
            completion(.success(false))
        })
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
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if (settings.authorizationStatus == .notDetermined) {
                    return completion(.success(false))
                }

                // Ignore other states, assuming we should not show the perm dialog (so return true)
                completion(.success(true))
            }
        }
    }

    func doVpnEnabled(completion: @escaping (Result<Granted, Error>) -> Void) {
        // If current value is non-nil, return immediately
        if let currentValue = writeVpnProfilePerms.value {
            completion(.success(currentValue))
            return
        }
        
        // Otherwise, wait for the next non-nil value
        writeVpnProfilePerms
            .compactMap { $0 } // Filter out nil values
            .first()           // Take the first non-nil value
            .sink(
                receiveCompletion: { result in
                    if case let .failure(error) = result {
                        completion(.failure(error))
                    }
                },
                receiveValue: { value in
                    completion(.success(value))
                }
            )
            .store(in: &cancellables)
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
    
    func doAskNotificationPerms(completion: @escaping (Result<Void, Error>) -> Void) {
        self.notification.askForPermissions()
            .receive(on: RunLoop.main)
            .sink()
            .store(in: &cancellables)
        completion(Result.success(()))
    }
    
    func doAskVpnPerms(completion: @escaping (Result<Void, Error>) -> Void) {
        self.permsRepo.askVpnProfilePerms()
            .receive(on: RunLoop.main)
            .sink(
                onFailure: { err in
                    completion(Result.failure(err))
                },
                onSuccess: {
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
                    return completion(Result.success(""))
                }
                return completion(Result.success(value))
            },
            onFailure: { err in
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
