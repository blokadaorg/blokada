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
        engine_logger("info")
        panic_hook { msg in
            if let msg = msg {
                Logger("Engine").e(String(cString: msg))
            }
        }
    }

    func generateKeypair() -> (String, String) {
       let keypair = keypair_new()!
       let privKey = String(cString: keypair.pointee.private_key)
       let pubKey = String(cString: keypair.pointee.public_key)
       keypair_free(keypair)
       return (privKey, pubKey)
   }

}
