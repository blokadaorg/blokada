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

var Mocks = MocksService()

class MocksService {

    func justAccount(_ id: String) -> AnyPublisher<Account, Error> {
        return Just(account(id))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    func account(_ id: String) -> Account {
        return Account(id: id, activeUntil: nil, active: false, type: "free")
    }

}
