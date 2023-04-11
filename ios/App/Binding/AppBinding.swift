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
import Factory

// Contains "main app state" mostly used in Home screen.
class AppBinding: AppOps, AppStartOps {
    var appStateHot: AnyPublisher<AppState, Never> {
        self.writeAppState.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var workingHot: AnyPublisher<Bool, Never> {
        self.writeWorking.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var pausedUntilHot: AnyPublisher<Date?, Never> {
        self.writePausedUntil.removeDuplicates().eraseToAnyPublisher()
    }

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    private lazy var timer = Services.timer

    fileprivate let writeAppState = CurrentValueSubject<AppState?, Never>(nil)
    fileprivate let writeWorking = CurrentValueSubject<Bool?, Never>(nil)
    fileprivate let writePausedUntil = CurrentValueSubject<Date?, Never>(nil)

    init() {
        AppOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        AppStartOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func pauseApp(until: Int?) -> AnyPublisher<Ignored, Error> {
        commands.execute(.pause)
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func unpauseApp() -> AnyPublisher<Ignored, Error> {
        commands.execute(.unpause)
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    func doAppStatusChanged(status: AppStatus,
                            completion: @escaping (Result<Void, Error>) -> Void) {
        writeWorking.send(status == .reconfiguring)
        if (status == .activatedCloud) {
            writeAppState.send(.Activated)
        } else if (status == .activatedPlus) {
            writeAppState.send(.Activated)
        } else if (status == .paused) {
            writeAppState.send(.Paused)
        } else {
            writeAppState.send(.Deactivated)
        }
        completion(Result.success(()))
    }

    func doAppPauseDurationChanged(seconds: Int64,
                                   completion: @escaping (Result<Void, Error>) -> Void) {
        writePausedUntil.send(Date().addingTimeInterval(Double(seconds)))
        completion(Result.success(()))
    }
}

extension Container {
    var app: Factory<AppBinding> {
        self { AppBinding() }.singleton
    }
}
