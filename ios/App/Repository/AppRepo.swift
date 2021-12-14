//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

// Contains "main app state" mostly used in Home screen.
class AppRepo {

    var activeHot: AnyPublisher<Bool, Never> {
        self.writeActive.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var ongoingHot: AnyPublisher<Bool, Never> {
        self.writeOngoing.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var accountType: AnyPublisher<AccountType, Never> {
        self.writeAccountType.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    fileprivate let writeActive = CurrentValueSubject<Bool?, Never>(nil)
    fileprivate let writeOngoing = CurrentValueSubject<Bool?, Never>(nil)
    fileprivate let writeAccountType = CurrentValueSubject<AccountType?, Never>(nil)

    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var dnsProfileActivatedHot = Repos.cloudRepo.dnsProfileActivatedHot
    private lazy var adblockingPausedHot = Repos.cloudRepo.adblockingPausedHot

    private var cancellables = Set<AnyCancellable>()
    private let recentAccountType = Atomic<AccountType>(AccountType.Libre)

    init() {
        onAnythingThatAffectsActiveStatusUpdateIt()
        onAccountChangeUpdateAccountType()
    }

    func onAnythingThatAffectsActiveStatusUpdateIt() {
        Publishers.CombineLatest(
            accountType,
            dnsProfileActivatedHot
        )
        .map { it -> Bool in
            let (accountType, dnsProfileActivated) = it

            if !accountType.isActive() {
                return false
            }

            if dnsProfileActivated {
                return true
            }

            return false
        }
        .sink(onValue: { it in self.writeActive.send(it) })
        .store(in: &cancellables)
    }

    func onAccountChangeUpdateAccountType() {
        accountHot.compactMap { it in it.account.type }
        .map { it in mapAccountType(it) }
        .sink(onValue: { it in
                self.recentAccountType.value = it
                self.writeAccountType.send(it)
        })
        .store(in: &cancellables)
    }

}
