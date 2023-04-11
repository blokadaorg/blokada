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

class PlusKeypairBinding: PlusKeypairOps {
    @Injected(\.flutter) private var flutter

    init() {
        PlusKeypairOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doGenerateKeypair(completion: @escaping (Result<PlusKeypair, Error>) -> Void) {
        let privKey = PrivateKey()
        let pubKey = privKey.publicKey
        completion(.success(PlusKeypair(
            publicKey: pubKey.base64Key,
            privateKey: privKey.base64Key
        )))
    }
}

extension Container {
    var plusKeypair: Factory<PlusKeypairBinding> {
        self { PlusKeypairBinding() }.singleton
    }
}
