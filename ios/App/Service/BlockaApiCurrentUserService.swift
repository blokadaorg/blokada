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

/**
 A wrapper on top of BlockaApiService that uses current user
 info to expose convenient api relevant to the current user.
 */
class BlockaApiCurrentUserService {

    lazy var client = Services.api

    private lazy var accountRepo = Repos.accountRepo

    func getAccountForCurrentUser() -> AnyPublisher<Account, Error> {
        return self.accountRepo.getAccount()
        .flatMap { it in
            self.client.getAccount(id: it.account.id)
        }
        .eraseToAnyPublisher()
    }

    func getDeviceForCurrentUser() -> AnyPublisher<DevicePayload, Error> {
        return self.accountRepo.getAccount()
        .flatMap { it in
            self.client.getDevice(id: it.account.id)
        }
        .eraseToAnyPublisher()
    }

    func putActivityRetentionForCurrentUser(_ retention: String) -> AnyPublisher<Ignored, Error> {
        return self.accountRepo.getAccount()
        .map { it in DeviceRequest(
            account_id: it.account.id,
            lists: nil,
            retention: retention,
            paused: nil
        )}
        .flatMap { it in self.client.putDevice(request: it) }
        .eraseToAnyPublisher()
    }

    func putPausedForCurrentUser(_ paused: Bool) -> AnyPublisher<Ignored, Error> {
        return self.accountRepo.getAccount()
        .map { it in DeviceRequest(
            account_id: it.account.id,
            lists: nil,
            retention: nil,
            paused: paused
        )}
        .flatMap { it in self.client.putDevice(request: it) }
        .eraseToAnyPublisher()
    }

    func postAppleCheckoutForCurrentUser(_ receipt: String) -> AnyPublisher<Account, Error> {
        return self.accountRepo.getAccount()
        .map { it in AppleCheckoutRequest(
            account_id: it.account.id,
            receipt: receipt
        )}
        .flatMap { it in self.client.postAppleCheckout(request: it) }
        .eraseToAnyPublisher()
    }

}
