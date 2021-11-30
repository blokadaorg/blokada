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
import UIKit

protocol BlockaApiServiceIn {
    func getAccount(id: AccountId) -> AnyPublisher<Account, Error>
    func postNewAccount() -> AnyPublisher<Account, Error>
}

class BlockaApiService2: BlockaApiServiceIn {

    private let log = Logger("BlockaApi")
    private let decoder = blockaDecoder
    private let encoder = blockaEncoder

    private lazy var client = Factories.http

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return self.client.get("/v1/account?account_id=\(id)")
            .decode(type: AccountWrapper.self, decoder: self.decoder)
            .map { result in
                return result.account
            }
            .eraseToAnyPublisher()
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return self.client.post("/v1/account", payload: nil)
            .decode(type: AccountWrapper.self, decoder: self.decoder)
            .map { result in
                return result.account
            }
            .eraseToAnyPublisher()
    }

}

class BlockaApiServiceMock: BlockaApiServiceIn {

    var mockAccount = { id in
        return Just(Account(id: id ?? "wearetesting", active_until: nil, active: false, type: "free"))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return mockAccount(id)
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return mockAccount(nil)
    }

}
