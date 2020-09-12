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
