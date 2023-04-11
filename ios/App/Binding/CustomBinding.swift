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

class CustomBinding: CustomOps {
    var allowed: [String] = []
    var onAllowed: ([String]) -> Void = { _ in }

    var denied: [String] = []
    var onDenied: ([String]) -> Void = { _ in }

    @Injected(\.flutter) private var flutter

    init() {
        CustomOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doCustomAllowedChanged(allowed: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        self.allowed = allowed
        onAllowed(allowed)
        completion(.success(()))
    }
    
    func doCustomDeniedChanged(denied: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        self.denied = denied
        onDenied(denied)
        completion(.success(()))
    }
}

extension Container {
    var custom: Factory<CustomBinding> {
        self { CustomBinding() }.singleton
    }
}
