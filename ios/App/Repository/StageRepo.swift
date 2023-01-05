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
import UIKit
import Combine

class StageRepo: Startable {

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

    fileprivate let writeStage = CurrentValueSubject<AppStage?, Never>(nil)

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "StageRepoBgQueue")
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    func start() {
        onBackground_StartBgTask()
        onForeground_StopBgTask()
    }

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

    // Asking OS for a bg task will give us ~30sec of execution time after going to bg.
    // We do this in order to give the app a chance to finish any pending requests etc.
    private func onBackground_StartBgTask() {
        stageHot
        .filter { it in it == AppStage.Background }
        .sink(onValue: { _ in
            self.bgTask = UIApplication.shared.beginBackgroundTask { [weak self] in
                // If asked by OS, end task
                self?.endBackgroundTask()
            }
            //assert(bgTask != .invalid)
        })
        .store(in: &cancellables)
    }

    private func onForeground_StopBgTask() {
        stageHot
        .filter { it in it == AppStage.Foreground }
        .sink(onValue: { _ in
            self.endBackgroundTask()
        })
        .store(in: &cancellables)
    }

    private func endBackgroundTask() {
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
    }

}

class DebugStageRepo: StageRepo {

    private let log = BlockaLogger("StageRepo")
    private var cancellables = Set<AnyCancellable>()

    override func start() {
        super.start()

        stageHot.sink(
            onValue: { it in self.log.w("Stage: \(it)") }
        )
        .store(in: &cancellables)
    }

    func injectForeground(isForeground: Bool) {
        writeStage.send( (isForeground ? AppStage.Foreground : AppStage.Background) )
    }

}
