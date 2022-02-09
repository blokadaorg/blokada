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

class NavRepo: Startable {

    var activeTabHot: AnyPublisher<Tab, Never> {
        self.writeActiveTab.compactMap { $0 }.eraseToAnyPublisher()
    }

    // Section identifies the second-level nav, like a detail screen.
    // This is a string specific to each tab.
    var sectionHot: AnyPublisher<Any?, Never> {
        writeSectionHot.eraseToAnyPublisher()
    }

    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot

    // Nil to not double send event on start, when also foreground even will come
    fileprivate let writeActiveTab = CurrentValueSubject<Tab?, Never>(nil)

    // Nil is valid and means tab's main screen
    fileprivate let writeSectionHot = CurrentValueSubject<Any?, Never>(nil)

    // Subscribers with lifetime same as the repository
    private var cancellables = Set<AnyCancellable>()

    func start() {
        listenToForegroundAndRepublishActiveTab()
    }

    func setActiveTab(_ tab: Tab) {
        writeActiveTab.send(tab)
        // This is how we navigate back from multi level navigation
        writeSectionHot.send(nil)
    }

    func setSection(_ section: Any?) {
        writeSectionHot.send(section)
    }

    func listenToForegroundAndRepublishActiveTab() {
        enteredForegroundHot
        .flatMap { _ in self.activeTabHot.first() }
        .sink(onValue: { it in self.writeActiveTab.send(it) })
        .store(in: &cancellables)
    }

}
