//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
