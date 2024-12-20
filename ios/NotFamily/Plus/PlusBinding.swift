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
import Combine

class PlusBinding: PlusOps {
    let plusEnabled = CurrentValueSubject<Bool, Never>(false)

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    init() {
        PlusOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func newPlus(_ gatewayPublicKey: String) {
        commands.execute(.newPlus, gatewayPublicKey)
    }

    func doPlusEnabledChanged(plusEnabled: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        self.plusEnabled.send(plusEnabled)
        completion(.success(()))
    }
}

extension Container {
    var plus: Factory<PlusBinding> {
        self { PlusBinding() }.singleton
    }
}
