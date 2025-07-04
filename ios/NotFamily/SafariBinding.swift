//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2025 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//


import Foundation
import Factory
import Combine
import Flutter

class SafariBinding: SafariOps {

    @Injected(\.flutter) private var flutter

    init() {
        SafariOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doOpenSafariSetup(completion: @escaping (Result<Void, any Error>) -> Void) {
        let url = URL(string: "https://go.blokada.org/howto/safari-extension")!
        UIApplication.shared.open(url)
        completion(Result.success(()))
    }
}

extension Container {
    var safari: Factory<SafariBinding> {
        self { SafariBinding() }.singleton
    }
}
