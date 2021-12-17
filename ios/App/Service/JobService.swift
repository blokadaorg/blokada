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

// JobService will notify the caller in the (near) future, through a cold publisher.
// It won't survive the app going to the background.
class JobService {

    func scheduleJob(when: Date) -> AnyPublisher<Ignored, Error> {
        return Future<Ignored, Error> { promise in
            DispatchQueue.main.asyncAfter(
                deadline: .now() + TimeInterval(when.timeIntervalSinceNow),
                execute: {
                    return promise(.success(true))
                }
            )
        }
        .eraseToAnyPublisher()
    }

}
