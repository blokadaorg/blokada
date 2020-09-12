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

struct LeaseViewModel {

    let lease: Lease

    private let log = Logger("Account")
    private let api = BlockaApiService.shared
    private let shared = SharedActionsService.shared

    var isMe: Bool {
        return lease.isMe()
    }

    var name: String {
        return lease.niceName()
    }

    init(mocked: String) {
        lease = Lease(account_id: mocked, public_key: "", gateway_id: "",
                      expires: "", alias: mocked, vip4: "", vip6: "")
    }

    init(_ lease: Lease) {
        self.lease = lease
    }
}

extension LeaseViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(lease.public_key)
    }
}

extension LeaseViewModel: Equatable {
    static func == (lhs: LeaseViewModel, rhs: LeaseViewModel) -> Bool {
        lhs.lease.public_key == rhs.lease.public_key
    }
}
