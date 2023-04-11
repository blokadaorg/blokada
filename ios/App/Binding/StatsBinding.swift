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

class StatsBinding: StatsOps {
    let blockedCounter = CurrentValueSubject<String, Never>("")

    @Injected(\.flutter) private var flutter

    init() {
        StatsOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doBlockedCounterChanged(blocked: String, completion: @escaping (Result<Void, Error>) -> Void) {
        blockedCounter.send(blocked)
        completion(.success(()))
    }
}

extension Container {
    var stats: Factory<StatsBinding> {
        self { StatsBinding() }.singleton
    }
}
