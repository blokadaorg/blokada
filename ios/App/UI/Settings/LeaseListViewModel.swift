//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

class LeaseListViewModel: ObservableObject {

    private lazy var leaseRepo = Repos.leaseRepo
    private lazy var accountRepo = Repos.accountRepo

    private var cancellables = Set<AnyCancellable>()

    @Published var leases = [LeaseViewModel]()

    init() {
        onLeasesChanged()
    }

    private func onLeasesChanged() {
        // Get latest leases and account info
        Publishers.CombineLatest(
            leaseRepo.leasesHot, accountRepo.accountHot
        )
        // Map each lease to isMe flag (if lease is for current device)
        .map { it -> Array<(Lease, Bool)> in
            let (leases, account) = it
            return leases.map { (
                $0, // Lease
                $0.public_key == account.keypair.publicKey // isMe
            ) }
        }
        .receive(on: RunLoop.main)
        // Put all this to views
        .sink(onValue: { it in
            self.leases = it.map { leaseAndMeFlag in
                let (lease, isMe) = leaseAndMeFlag
                return LeaseViewModel(lease, isMe: isMe)
            }
        })
        .store(in: &cancellables)
    }

    func deleteLease(_ index: IndexSet) {
        let lease = leases[index.first!]
        if !lease.isMe {
            leaseRepo.deleteLease(lease.lease)
        }
    }

    func refreshLeases() {
        leaseRepo.refreshLeases()
    }

}
