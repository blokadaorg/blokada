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
    func generateKeypair() -> AnyPublisher<BlockaKeypair, Error>
}

// Simple rotation of actually valid keypairs that are used for Mocked build and testing.
// They are rejected in Production builds (in AccountRepo).
class CryptoServiceMock: CryptoServiceIn {

    private var lastKeypair = -1

    func generateKeypair() -> AnyPublisher<BlockaKeypair, Error> {
        lastKeypair = (lastKeypair + 1) % CRYPTO_MOCKED_KEYS.count
        return Just(CRYPTO_MOCKED_KEYS[lastKeypair])
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

}

var CRYPTO_MOCKED_KEYS = [
    BlockaKeypair(
        privateKey: "yJQ0EKiz3UQY89gGJOcPf0WyiCOOSWq6arid1DJLQa0=",
        publicKey: "eBQoke+riA0RCKV0Vhfk+h5M6npkaa9VDnnTibI0/RM="
    ),
    BlockaKeypair(
        privateKey: "F6POp9J0YE9wIcloDcqYgoccLpRwpMb3CP4zp9XPYkg=",
        publicKey: "wpgZet7AJp/HgeDVgRKB6ZF3N9SCXmUMqY1D4sY04EM="
    ),
    BlockaKeypair(
        privateKey: "dhKR6Edo2G7gwx5/99JS3x7j9D4uBYsykxCsBeAYqlM=",
        publicKey: "xTgsjuiqI17XY5ur8MmXDUfgg45qqxNzHnBWi9YNbTI="
    ),
    BlockaKeypair(
        privateKey: "tHCBZw+p84NSQxGEsyHYdmjSHWywkWX+0M9XnrnDYtE=",
        publicKey: "pi2dyOBzQWjt79IebljEc5fGJhDS/JUDjFK0QG6EPXI="
    ),
    BlockaKeypair(
        privateKey: "1GAFpzwHd9aD5/+acIdcCDsIEWuZWw3yupp7b33Fg+I=",
        publicKey: "t3RqWLB9t7MsZjYH/Yu/hIFT15AW+AvSTuv+ePEXmEg="
    ),
    BlockaKeypair(
        privateKey: "BM+5CDgC8Xr16Xn2k7iKIbdWhEUTfmkWHDV4hNvxot8=",
        publicKey: "vBdd53xYSFmPq7CioyrQgwtMDoDvzj9mS//LsJJX2VE="
    )
]
