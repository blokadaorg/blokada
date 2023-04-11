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

struct LeaseViewModel {

    let lease: Lease
    let isMe: Bool

    var name: String {
        return lease.niceName()
    }

    init(mocked: String) {
        lease = Lease(accountId: mocked, publicKey: "", gatewayId: "",
                      expires: "", alias: mocked, vip4: "", vip6: "")
        isMe = false
    }

    init(_ lease: Lease, isMe: Bool) {
        self.lease = lease
        self.isMe = isMe
    }
}

extension LeaseViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(lease.publicKey)
    }
}

extension LeaseViewModel: Equatable {
    static func == (lhs: LeaseViewModel, rhs: LeaseViewModel) -> Bool {
        lhs.lease.publicKey == rhs.lease.publicKey
    }
}
