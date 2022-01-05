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

class StageRepo {

    // Current app stage from the AppDelegate or SceneDelegate (Creating, Foreground, etc)
    var stageHot: AnyPublisher<AppStage, Never> {
        self.writeStage.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    // Filtered IsForeground = true events, debounced to avoid user flippy-flap
    var enteredForegroundHot: AnyPublisher<IsForeground, Never> {
        stageHot
        .filter { it in it == AppStage.Foreground }
        .debounce(for: 1, scheduler: bgQueue)
        .map { _ in true }
        .eraseToAnyPublisher()
    }

    // Event named "Creating". Sent only once on app creation.
    var creatingHot: AnyPublisher<Ignored, Never> {
        stageHot
        .filter { it in it == AppStage.Creating }
        .map { _ in (true) }
        .eraseToAnyPublisher()
    }

    // Event named "Destroying". Sent only once when app is being removed from memory.
    var destroyingHot: AnyPublisher<Ignored, Never> {
        stageHot
        .filter { it in it == AppStage.Destroying }
        .map { _ in (true) }
        .eraseToAnyPublisher()
    }

    private let bgQueue = DispatchQueue(label: "StageRepoBgQueue")

    fileprivate let writeStage = CurrentValueSubject<AppStage?, Never>(nil)

    func onCreate() {
        writeStage.send(AppStage.Creating)
    }

    func onForeground() {
        writeStage.send(AppStage.Foreground)
    }

    func onBackground() {
        writeStage.send(AppStage.Background)
    }

    func onDestroy() {
        writeStage.send(AppStage.Destroying)
    }

}

class DebugStageRepo: StageRepo {

    private let log = Logger("StageRepo")
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        stageHot.sink(
            onValue: { it in self.log.v("Stage: \(it)") }
        )
        .store(in: &cancellables)
    }

    func injectForeground(isForeground: Bool) {
        writeStage.send( (isForeground ? AppStage.Foreground : AppStage.Background) )
    }

}
