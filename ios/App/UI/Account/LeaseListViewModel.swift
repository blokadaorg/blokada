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

    private let leaseRepo = Repos.leaseRepo

    private var cancellables = Set<AnyCancellable>()

    @Published var leases = [LeaseViewModel]()

    init() {
        onLeasesChanged()
    }

    private func onLeasesChanged() {
        leaseRepo.leasesHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.leases = it.map { lease in
                LeaseViewModel(lease)
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
