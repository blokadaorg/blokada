//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import Factory

class RateService: Startable {
    @Injected(\.app) private var app
    @Injected(\.stage) private var stage

    private lazy var persistence = Services.persistenceRemote

    private lazy var appStateHot = app.appStateHot
    private lazy var sheetRepo = stage

    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "StageRepoBgQueue")

    func start() {
//        onSecondRunActivation_ShowRateSheet()
//        onDeactivating_PersistAppStartedBefore()
    }

//    private func onSecondRunActivation_ShowRateSheet() {
//        Publishers.CombineLatest(
//            stageRepo.enteredForegroundHot, appStateHot
//        )
//        .filter { it in
//            let (enteredFg, appState) = it
//            return enteredFg && appState == .Activated
//        }
//        .flatMap { _ in
//            Publishers.CombineLatest(
//                self.persistence.getBool(forKey: "appStartedBefore"),
//                self.persistence.getBool(forKey: "rateSheetShown")
//            )
//        }
//        .delay(for: 2.0, scheduler: bgQueue)
//        .sink(onValue: { it in
//            let (appStartedBefore, rateSheetShown) = it
//            if appStartedBefore && !rateSheetShown {
//                self.sheetRepo.stage.showModal(.RateApp)
//                self.persistence.setBool(true, forKey: "rateSheetShown")
//            }
//        })
//        .store(in: &cancellables)
//    }

//    private func onDeactivating_PersistAppStartedBefore() {
//        stageRepo.destroyingHot
//        .sink(onValue: { _ in
//            self.persistence.setBool(true, forKey: "appStartedBefore")
//        })
//        .store(in: &cancellables)
//    }

}
