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
import Factory

/**
 A wrapper on top of BlockaApiService that uses current user
 info to expose convenient api relevant to the current user.
 */
class BlockaApiCurrentUserService {

    lazy var client = Services.api

    private lazy var accountRepo = account
    @Injected(\.env) private var envRepo
    @Injected(\.account) private var account

//    func postAppleCheckoutForCurrentUser(_ receipt: String) -> AnyPublisher<JsonAccount, Error> {
//        return accountRepo.accountHot.first()
//        .map { it in AppleCheckoutRequest(
//            account_id: it.account.id,
//            receipt: receipt
//        )}
//        .flatMap { it in self.client.postAppleCheckout(request: it) }
//        .eraseToAnyPublisher()
//    }
//
//    func postAppleDeviceTokenForCurrentUser(deviceToken: Data) -> AnyPublisher<Ignored, Error> {
//        return accountRepo.accountHot.first()
//        .map { it in AppleDeviceTokenRequest(
//            account_id: it.account.id,
//            public_key: it.keypair.publicKey,
//            device_token: deviceToken
//        )}
//        .flatMap { it in self.client.postAppleDeviceToken(request: it) }
//        .eraseToAnyPublisher()
//    }

}
