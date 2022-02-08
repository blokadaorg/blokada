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

protocol CryptoServiceIn {
    func generateKeypair() -> AnyPublisher<Keypair, Error>
}

class CryptoServiceMock: CryptoServiceIn {
    func generateKeypair() -> AnyPublisher<Keypair, Error> {
        return Just(
            Keypair(
                privateKey: CRYPTO_MOCKED_PRIVKEY,
                publicKey: CRYPTO_MOCKED_PUBKEY
            )
        )
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
}

var CRYPTO_MOCKED_PRIVKEY = "mocked-private-key"
var CRYPTO_MOCKED_PUBKEY = "mocked-public-key"
