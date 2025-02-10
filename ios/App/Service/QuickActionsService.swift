//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import UIKit
import SwiftUI
import Combine
import Factory

var PAUSE_TIME_SECONDS = 300

class QuickActionsService: Startable {

    @Injected(\.app) private var app

    private lazy var appRepo = app
    private var cancellables = Set<AnyCancellable>()

    private let actionStart = UIApplicationShortcutItem(
        type: "start",
        localizedTitle: L10n.homePowerActionTurnOn,
        localizedSubtitle: "",
        icon: UIApplicationShortcutIcon(systemImageName: Image.fPower),
        userInfo: nil
    )

    private let actionStop = UIApplicationShortcutItem(
        type: "stop",
        localizedTitle: L10n.homePowerActionTurnOff,
        localizedSubtitle: "",
        icon: UIApplicationShortcutIcon(systemImageName: Image.fPower),
        userInfo: nil
    )

    private let actionPause = UIApplicationShortcutItem(
        type: "pause",
        localizedTitle: L10n.homePowerActionPause,
        localizedSubtitle: "",
        icon: UIApplicationShortcutIcon(systemImageName: Image.fPause),
        userInfo: nil
    )

    func start() {
        onAppState()
    }

    func onQuickAction(_ type: String) {
        BlockaLogger.v("QuickAction", "Received quick action: \(type)")

        if type == "start" {
            appRepo.unpauseApp()
        } else if type == "stop" {
            appRepo.pauseApp(until: nil)
        } else if type == "pause" {
            appRepo.pauseApp(until: 30)
        } else {
            BlockaLogger.w("QuickAction", "Unknown action, ignoring")
        }
    }

    private func onAppState() {
        Publishers.CombineLatest(
            appRepo.appStateHot, appRepo.pausedUntilHot
        )
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            let (appState, pausedUntil) = it
            self.removeAllActions()
            if appState == .Paused && pausedUntil != nil {
                self.addAction(self.actionStart)
                self.addAction(self.actionStop)
            } else if appState == .Activated {
                self.addAction(self.actionStop)
                self.addAction(self.actionPause)
            } else {
                self.addAction(self.actionStart)
            }
        })
        .store(in: &cancellables)
    }

    private func removeAllActions() {
        UIApplication.shared.shortcutItems?.removeAll()
    }

    private func addAction(_ action: UIApplicationShortcutItem) {
        var shortcutItems = UIApplication.shared.shortcutItems ?? []
        shortcutItems.append(action)
        UIApplication.shared.shortcutItems = shortcutItems
    }

}
