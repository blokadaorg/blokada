//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class EngineService {

    static let shared = EngineService()

    private init() {
        // singleton
    }

    func panicHook() {

    }

    func generateKeypair() -> (String, String) {
        return ("mocked-private-key", "mocked-public-key")
    }

}
