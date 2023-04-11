//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import UIKit

class AppleTokenService {

    fileprivate let sendAppleTokenT = Tasker<AppleToken, Ignored>("sendAppleToken")

    private lazy var api = Services.apiForCurrentUser
    private lazy var notification = Services.notification

    private var cancellables = Set<AnyCancellable>()

    init(_ app: UIApplication) {
        app.registerForRemoteNotifications()
        notification.registerNotifications()
        onSendAppleToken()
    }

    func onAppleTokenReceived(_ appleToken: AppleToken) {
        sendAppleTokenT.send(appleToken)
    }

    func onAppleTokenFailed(_ err: Error) {
        BlockaLogger.w("AppleToken", "Failed registering for remote notifications: \(err)")
    }

    private func onSendAppleToken() {
//        sendAppleTokenT.setTask { appleToken in Just(appleToken)
//            .flatMap { it in self.api.postAppleDeviceTokenForCurrentUser(deviceToken: it) }
//            .eraseToAnyPublisher()
//        }
    }

}
