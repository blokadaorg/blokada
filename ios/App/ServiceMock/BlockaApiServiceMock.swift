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

class BlockaApiServiceMock: BlockaApiServiceIn {

    var mockAccount = { id in
        Mocks.justAccount(id ?? "wearetesting")
    }

    func getAccount(id: AccountId) -> AnyPublisher<Account, Error> {
        return mockAccount(id)
    }

    func postNewAccount() -> AnyPublisher<Account, Error> {
        return mockAccount(nil)
    }

}
