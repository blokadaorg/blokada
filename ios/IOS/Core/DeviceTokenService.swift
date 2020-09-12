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

class DeviceTokenService {

    static let shared = DeviceTokenService()

    private init() { }

    private let log = Logger("Token")
    private let api = BlockaApiService.shared

    func startObserving() {
        self.log.v("Started observing device tokens")
        Config.shared.setOnDeviceUpdated {
            self.updateDeviceToken()
        }
    }

    private func updateDeviceToken() {
        onBackground {
            let cfg = Config.shared
            if let token = cfg.deviceToken(), cfg.hasAccount(), cfg.hasKeys() {
                self.log.v("Registering new device token")
                let request = AppleDeviceTokenRequest(
                    account_id:  cfg.accountId(),
                    public_key: cfg.publicKey(),
                    device_token: token
                )
                self.api.postAppleDeviceToken(request: request) { error in
                    if let error = error {
                        self.log.w("Could not register device token".cause(error.localizedDescription))
                    }
                }
            }
        }
    }
}
