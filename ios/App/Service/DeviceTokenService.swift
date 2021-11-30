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
