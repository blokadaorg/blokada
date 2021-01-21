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

class ExpirationService {

    static let shared = ExpirationService()

    private let log = Logger("Expire")

    private init() {}

    private var onExpired = {}

    func setOnExpired(callback: @escaping () -> Void) {
        onMain {
            self.onExpired = callback
        }
    }

    func update(_ lease: Lease?) {
        onBackground {
            let when = lease?.activeUntil() ?? Date()
            if when <= Date() {
                return self.checkExpiration()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(when.timeIntervalSinceNow), execute: {
                self.checkExpiration()
            })
        }
    }

    private func checkExpiration() {
        onMain {
            if Config.shared.hasLease() {
                self.log.v("checkExpiration: executing")
                self.onExpired()
            }
        }
    }

}
