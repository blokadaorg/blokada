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

struct CurrentLease {
    let lease: Lease?
}

class LeaseRepo: Startable {

    var leasesHot: AnyPublisher<[Lease], Never> {
        writeLeases.compactMap { $0 }.eraseToAnyPublisher()
    }

    var currentHot: AnyPublisher<CurrentLease, Never> {
        writeCurrent.compactMap { $0 }
        .removeDuplicates { a, b in a.lease == b.lease }
        .eraseToAnyPublisher()
    }

    private lazy var persistence = Services.persistenceLocal
    private lazy var api = Services.apiForCurrentUser
    private lazy var dialog = Services.dialog
    private lazy var timer = Services.timer
    private lazy var env = Services.env

    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot
    private lazy var gatewayRepo = Repos.gatewayRepo

    fileprivate let writeLeases = CurrentValueSubject<[Lease]?, Never>(nil)
    fileprivate let writeCurrent = CurrentValueSubject<CurrentLease?, Never>(nil)

    fileprivate let loadLeasesT = SimpleTasker<Ignored>("loadLeases")
    fileprivate let loadCurrentLeaseT = SimpleTasker<Ignored>("loadCurrentLease")
    fileprivate let newLeaseT = Tasker<GatewayId, Ignored>("newLease")
    fileprivate let deleteLeaseT = Tasker<Lease, Ignored>("deleteLease")

    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "LeaseRepoBgQueue")

    func start() {
        onLoadLeases()
        onLeaseOrAccountChange_FindCurrentLease()
        onNewLease()
        onDeleteLease()
        onCurrentLease_ManageExpiration()
        onForeground_RefreshLeases()
        onAccountNotPlus_RemoveLease()
    }

    func refreshLeases() -> AnyPublisher<Ignored, Error> {
        return loadLeasesT.send()
    }

    func newLease(_ gw: GatewayId) -> AnyPublisher<Ignored, Error> {
        return newLeaseT.send(gw)
    }

    func deleteLease(_ lease: Lease) -> AnyPublisher<Ignored, Error> {
        return deleteLeaseT.send(lease)
    }

    private func onLoadLeases() {
        loadLeasesT.setTask { _ in Just(true)
            .flatMap { _ in self.api.getLeasesForCurrentUser() }
            .map { it in self.writeLeases.send(it) }
            .map { _ in true }
//            .tryCatch { err -> AnyPublisher<Ignored, Error> in
//                BlockaLogger.e("LeaseRepo", "Could not fetch leases, assuming none: \(err)")
//                self.writeLeases.send([])
//                throw err
//            }
            .eraseToAnyPublisher()
        }
    }

    private func onLeaseOrAccountChange_FindCurrentLease() {
        Publishers.CombineLatest(
            leasesHot, self.accountHot
        )
        .sink(onValue: { it in
            let (leases, accountWithKeypair) = it
            if accountWithKeypair.account.isActive(),
                let current = leases.first(where: { lease in
                    lease.public_key == accountWithKeypair.keypair.publicKey
                })
            {
                self.writeCurrent.send(CurrentLease(lease: current))
            } else {
                self.writeCurrent.send(CurrentLease(lease: nil))
            }
        })
        .store(in: &cancellables)
    }

    private func onNewLease() {
        newLeaseT.setTask { gatewayId in Just(gatewayId)
            .flatMap { _ in self.accountHot.first() }
            .map { it in LeaseRequest(
                account_id: it.account.id,
                public_key: it.keypair.publicKey,
                gateway_id: gatewayId,
                alias: self.env.aliasForLease
            )}
            .flatMap { request in
                self.api.client.postLease(request: request)
                .tryCatch { err -> AnyPublisher<Lease, Error> in
                    // Too many leases, try to remove one with the alias of current device
                    // This may happen if user regenerated keys (reinstall)
                    if let e = err as? CommonError, e == CommonError.tooManyLeases {
                        return self.api.deleteLeasesForCurrentUserAndDevice()
                        .flatMap { _ in self.api.client.postLease(request: request) }
                        .eraseToAnyPublisher()
                    } else {
                        throw err
                    }
                }
            }
            .flatMap { _ in self.refreshLeases() }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onDeleteLease() {
        deleteLeaseT.setTask { lease in Just(lease)
            .map { _ in LeaseRequest(
                account_id: lease.account_id,
                public_key: lease.public_key,
                gateway_id: lease.gateway_id,
                alias: lease.alias
            )}
            .flatMap { request in
                self.api.client.deleteLease(request: request)
            }
            .flatMap { _ in self.refreshLeases() }
            .map { _ in true }
            .eraseToAnyPublisher()
        }
    }

    private func onCurrentLease_ManageExpiration() {
        currentHot
        // Allow other components (like VPN) settle before potentially stopping them
        .delay(for: 4.0, scheduler: bgQueue)
        .sink(onValue: { it in
            if let lease = it.lease {
                let expireAt = lease.activeUntil().shortlyBefore()
                if expireAt < Date() {
                    // The new lease we got is limited by account expiration.
                    // Assume we are expiring and delete the lease.
                    BlockaLogger.w("LeaseRepo", "Account is probably about to expire")
                    self.deleteLease(lease)
                    self.dialog.showAlert(
                        message: L10n.notificationVpnExpiredBody,
                        header: L10n.notificationVpnExpiredSubtitle
                    )
                    .sink()
                    .store(in: &self.cancellables)
                    return
                }

                self.timer.createTimer(NOTIF_LEASE_EXP, when: expireAt)
                .flatMap { _ in self.timer.obtainTimer(NOTIF_LEASE_EXP) }
                .sink(
                    onFailure: { err in
                        BlockaLogger.e("LeaseRepo", "Lease expiration timer failed: \(err)")
                    },
                    onSuccess: {
                        BlockaLogger.w("LeaseRepo", "Lease expired, refreshing")
                        self.newLease(lease.gateway_id)
                    }
                )
                .store(in: &self.cancellables) // TODO: not sure if it's the best idea
            } else {
                self.timer.cancelTimer(NOTIF_LEASE_EXP)
                .sink()
                .store(in: &self.cancellables)
            }
        })
        .store(in: &cancellables)
    }

    private func onForeground_RefreshLeases() {
        enteredForegroundHot
        .debounce(for: 3.0, scheduler: bgQueue)
        .sink(onValue: { _ in self.refreshLeases() })
        .store(in: &cancellables)
    }

    private func onAccountNotPlus_RemoveLease() {
        accountHot
        .delay(for: 3.0, scheduler: bgQueue)
        .tryMap { it in mapAccountType(it.account.type) }
        .filter { it in it != .Plus }
        .flatMap { _ in self.currentHot.first() }
        .compactMap { it in it.lease }
        .sink(onValue: { currentLease in
            BlockaLogger.w("LeaseRepo", "Removing lease because account is not plus")
            self.deleteLease(currentLease)
        })
        .store(in: &cancellables)
    }

}
