//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

class NotificationBinding: NotificationOps {
    @Injected(\.flutter) private var flutter
    
    lazy var service = Services.notification

    init() {
        NotificationOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doShow(notificationId: String, when: String, completion: @escaping (Result<Void, Error>) -> Void) {
        //let whenDate = Date().addingTimeInterval(40)
        let whenDate = when.toDate
        service.scheduleNotification(id: notificationId, when: whenDate)
        .sink(onFailure: { err in
            completion(.failure(err))
        }, onSuccess: {
            // Success is emitted only once the notification is triggerred
        })
        completion(.success(()))
    }
    
    func doDismissAll(completion: @escaping (Result<Void, Error>) -> Void) {
        service.clearAllNotifications()
        completion(.success(()))
    }
}

extension Container {
    var notification: Factory<NotificationBinding> {
        self { NotificationBinding() }.singleton
    }
}
