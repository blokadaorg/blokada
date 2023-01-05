//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation

struct BlockaKeypair: Codable {
    let privateKey: BlockaPrivateKey
    let publicKey: BlockaPublicKey
}

extension BlockaKeypair : Equatable {
    static func == (lhs: BlockaKeypair, rhs: BlockaKeypair) -> Bool {
        return
            lhs.privateKey == rhs.privateKey &&
            lhs.publicKey == rhs.publicKey
    }
}

struct AccountWithKeypair {
    let account: Account
    let keypair: BlockaKeypair
}
