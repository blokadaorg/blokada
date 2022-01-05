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

// An interface to Rust-based Blocka Engine lib.
// Currently only used for keypair generation.
class EngineService {

    init() {
        registerPanicHook()
    }

    private func registerPanicHook() {
        engine_logger("info")
        panic_hook { msg in
            if let msg = msg {
                Logger("Engine").e(String(cString: msg))
            }
        }
    }

    func generateKeypair() -> Keypair {
        let keypair = keypair_new()!
        let privKey = String(cString: keypair.pointee.private_key)
        let pubKey = String(cString: keypair.pointee.public_key)
        keypair_free(keypair)
        return Keypair(privateKey: privKey, publicKey: pubKey)
   }

}
