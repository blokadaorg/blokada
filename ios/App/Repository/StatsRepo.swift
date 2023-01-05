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

class StatsRepo: Startable {

    var blockedHot: AnyPublisher<Int, Never> {
        statsHot.map { it in Int(it.total_blocked) }.compactMap { $0 }
        .eraseToAnyPublisher()
    }

    var statsHot: AnyPublisher<CounterStats, Never> {
        writeStats.compactMap { $0 }.eraseToAnyPublisher()
    }

    private lazy var api = Services.apiForCurrentUser

    private lazy var accountIdHot = Repos.accountRepo.accountIdHot
    private lazy var enteredForegroundHot =  Repos.stageRepo.enteredForegroundHot
    private lazy var activityEntriesHot = Repos.activityRepo.entriesHot

    fileprivate let writeStats = CurrentValueSubject<CounterStats?, Never>(nil)

    fileprivate let refreshStatsT = SimpleTasker<Ignored>("refreshStats", debounce: 3.0)

    private var cancellables = Set<AnyCancellable>()

    func start() {
        onRefreshStats()
        onAccountIdChange_refreshStats()
        onForeground_refreshStats()
        onActivityChanged_refreshStats()
    }

    private func onRefreshStats() {
        refreshStatsT.setTask { _ in Just(true)
            .flatMap { _ in self.api.getStatsForCurrentUser() }
            .tryMap { it in self.writeStats.send(it) }
            .tryMap { _ in true }
            .eraseToAnyPublisher()
        }
    }

    // Refresh on account ID changed, will also trigger when starting the app
    private func onAccountIdChange_refreshStats() {
        accountIdHot
        .sink(onValue: { _ in self.refreshStatsT.send() })
        .store(in: &cancellables)
    }

    private func onForeground_refreshStats() {
        enteredForegroundHot
        .sink(onValue: { _ in self.refreshStatsT.send() })
        .store(in: &cancellables)
    }

    private func onActivityChanged_refreshStats() {
        activityEntriesHot
        .sink(onValue: { _ in self.refreshStatsT.send() })
        .store(in: &cancellables)
    }

}
