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

class NavRepo {

    var activeTabHot: AnyPublisher<Tab, Never> {
        self.writeActiveTab.compactMap { $0 }.eraseToAnyPublisher()
    }

    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot

    // Nil to not double send event on start, when also foreground even will come
    fileprivate let writeActiveTab = CurrentValueSubject<Tab?, Never>(nil)

    private let recentTab = Atomic<Tab>(Tab.Home)

    // Subscribers with lifetime same as the repository
    private var cancellables = Set<AnyCancellable>()

    init() {
        listenToForegroundAndRepublishActiveTab()
    }

    func setActiveTab(_ tab: Tab) {
        writeActiveTab.send(tab)
    }

    func listenToForegroundAndRepublishActiveTab() {
        enteredForegroundHot
        .map { _ in self.recentTab.value }
        .sink(onValue: { it in self.writeActiveTab.send(it) })
        .store(in: &cancellables)
    }
}
