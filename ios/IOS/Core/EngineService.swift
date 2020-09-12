//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
