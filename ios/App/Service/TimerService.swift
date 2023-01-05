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

// TimerService is used for setting pause timer, expiration notifications etc.
// Anything that needs to happen in the future. It uses several methods to make the timer
// as reliable on iOS as possible, and surviving app reinitializations (uses persistence).
class TimerService {

    private lazy var storage = Services.persistenceLocal
    private lazy var notification = Services.notification
    private lazy var job = Services.job

    private let dateFormatter = blockaDateFormatter

    func createTimer(_ id: String, when: Date) -> AnyPublisher<Ignored, Error> {
        BlockaLogger.v("Timer", "Creating timer for: \(id), at: \(when)")
        return storage.setString(blockaDateFormatter.string(from: when), forKey: "timer_\(id)")
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

    // Returns a publisher that will finish exactly when this timer expires.
    func obtainTimer(_ id: String) -> AnyPublisher<Ignored, Error> {
        BlockaLogger.v("Timer", "Obtaining timer for: \(id)")
        return getTimerDate(id)
        .flatMap { when -> AnyPublisher<Ignored, Error> in
            if when <= Date() {
                // Time's up, cancel timer and finish immediatelly
                return self.cancelTimer(id)
            } else {
                // Wait for any of the mechanisms to deliver the callback
                return Publishers.Merge(
                    self.job.scheduleJob(when: when),
                    // For notifications, it can fail if no perms.
                    // Just ignore the output, and wait for the above job to finish.
                    self.notification.scheduleNotification(id: id, when: when)
                    .tryCatch { err -> AnyPublisher<Ignored, Error> in
                        BlockaLogger.w("Timer", "Notification failed to set, ignoring: \(err)")
                        return Just(true)
                        .setFailureType(to: Error.self)
                        .ignoreOutput()
                        .eraseToAnyPublisher()
                    }
                )
                .first()
                // Check if timer hasn't been updated in the meantime
                .flatMap { _ in
                    self.storage.getString(forKey: "timer_\(id)")
                }
                .tryMap { it in self.dateFormatter.date(from: it) }
                .tryMap { it -> Date in
                    if it == nil {
                        throw "timer cancelled in the meantime"
                    } else {
                        return it!
                    }
                }
                .tryMap { whenShouldTrigger -> Bool in
                    if whenShouldTrigger > Date() {
                        throw "timer updated in the meantime"
                    } else {
                        return true
                    }
                }
                // Timer is done now, cancel it and finish
                .tryMap { it in
                    self.cancelTimer(id)
                    return it
                }
                .eraseToAnyPublisher()
            }
        }
        .eraseToAnyPublisher()
    }

    func getTimerDate(_ id: String) -> AnyPublisher<Date, Error> {
        return storage.getString(forKey: "timer_\(id)")
        .tryMap { it in self.dateFormatter.date(from: it) }
        .tryMap { it -> Date in
            if it == nil {
                throw "could not read timer date"
            } else {
                return it!
            }
        }
        .eraseToAnyPublisher()
    }

    func cancelTimer(_ id: String) -> AnyPublisher<Ignored, Error> {
        BlockaLogger.v("Timer", "Cancelling timer for: \(id)")
        return storage.delete(forKey: "timer_\(id)")
        .tryMap { _ in true }
        .eraseToAnyPublisher()
    }

}
