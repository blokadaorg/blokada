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

    func getParentDeviceProtectionOwner(completion: @escaping (Result<String, Error>) -> Void) {
        guard flutter.isFlavorFamily else {
            completion(.success(BlokadaSixProtectionOwnerMarker.ownerNone))
            return
        }

        guard canOpenBlokadaSix() else {
            completion(.success(BlokadaSixProtectionOwnerMarker.ownerNone))
            return
        }

        guard let storage = UserDefaults(
            suiteName: BlokadaSixProtectionOwnerMarker.storageSuite
        ) else {
            completion(.success(BlokadaSixProtectionOwnerMarker.ownerBlokadaSix))
            return
        }

        let owner = storage.string(forKey: BlokadaSixProtectionOwnerMarker.ownerKey)
        let updatedAt = storage.double(forKey: BlokadaSixProtectionOwnerMarker.updatedAtKey)
        let isFresh = BlokadaSixProtectionOwnerMarker.isFresh(updatedAt: updatedAt)

        if owner == BlokadaSixProtectionOwnerMarker.ownerNone && isFresh {
            completion(.success(BlokadaSixProtectionOwnerMarker.ownerNone))
            return
        }

        if owner == BlokadaSixProtectionOwnerMarker.ownerBlokadaSix && isFresh {
            completion(.success(BlokadaSixProtectionOwnerMarker.ownerBlokadaSix))
            return
        }

        completion(.success(BlokadaSixProtectionOwnerMarker.ownerBlokadaSix))
    }

    /// iOS does not expose another app's active DNS/VPN profile. If Blokada 6
    /// is installed but has not yet written a fresh marker, Family assumes the
    /// parent wants to keep managing this device in Blokada 6 and stays out.
    private func canOpenBlokadaSix() -> Bool {
        guard let url = URL(string: "six://") else { return false }
        return UIApplication.shared.canOpenURL(url)
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

    func getPrivateDnsState(completion: @escaping (Result<PrivateDnsState, any Error>) -> Void) {
        privateDns.getPrivateDnsState()
        .sink(
            onValue: { value in
                let state = PrivateDnsState(
                    kind: self.mapPrivateDnsStateKind(value.kind),
                    serverUrl: value.serverUrl
                )
                completion(Result.success(state))
            },
            onFailure: { err in
                completion(Result.failure(err))
            }
        )
        .store(in: &cancellables)
    }

    func isRunningOnMac(completion: @escaping (Result<Bool, any Error>) -> Void) {
        // Check if this is an iPad app running on macOS
        if #available(iOS 14.0, *) {
            let isOnMac = ProcessInfo.processInfo.isiOSAppOnMac
            completion(Result.success(isOnMac))
        } else {
            // iOS versions before 14.0 cannot run on Mac
            completion(Result.success(false))
        }
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

    private func mapPrivateDnsStateKind(_ kind: PrivateDnsProfileStateKind) -> PrivateDnsStateKind {
        switch kind {
        case .enabled:
            return .enabled
        case .disabled:
            return .disabled
        case .unavailable:
            return .unavailable
        }
    }
}

extension Container {
    var perm: Factory<PermBinding> {
        self { PermBinding() }.singleton
    }
}
