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

class LeaseListViewModel: ObservableObject {

    @Published var leases = [LeaseViewModel]()

    private let log = Logger("Account")
    private let api = BlockaApiService.shared
    private let shared = SharedActionsService.shared

    init() {
        shared.refreshLeases = refreshLeases
    }

    func refreshLeases() {
        onBackground {
            self.api.getLeases(id: Config.shared.accountId()) { error, leases in onMain {
                guard error == nil else {
                    return self.log.e("Could not refresh leases".cause(error))
                }

                self.leases = leases!.map { lease in
                    LeaseViewModel(lease)
                }

                self.log.v("Leases refreshed")
            }}
        }
    }

    func deleteLease(_ index: IndexSet) {
        let lease = leases[index.first!]
        if !lease.isMe {
            onBackground {
                let leaseRequest = LeaseRequest(
                    account_id: Config.shared.accountId(),
                    public_key: lease.lease.public_key,
                    gateway_id: lease.lease.gateway_id,
                    alias: nil
                )

                self.api.deleteLease(request: leaseRequest) { error, leases in onMain {
                    guard error == nil else {
                       return self.log.e("Could not refresh leases".cause(error))
                    }

                    self.log.v("Lease deleted")
                    self.refreshLeases()
                }}
            }
        }
    }
}
