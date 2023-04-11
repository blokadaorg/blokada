//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import Factory

class TabViewModel : ObservableObject {
    @Injected(\.stage) private var stage

    @Published var activeTab: Tab = .Home
    @Published var tabPayload = [String]()
    @Published var showNavBar = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        onTabChanged()
        onTabPayloadChanged()
        onShowNavbar()
    }

    private func onTabChanged() {
        stage.activeTab
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.activeTab = it })
        .store(in: &cancellables)
    }

    private func onTabPayloadChanged() {
        stage.tabPayload
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            if let it = it {
                self.tabPayload = [it]
            } else {
                self.tabPayload = []
            }
        })
        .store(in: &cancellables)
    }

    private func onShowNavbar() {
        stage.showNavbar
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.showNavBar = it })
        .store(in: &cancellables)
    }

    func setActiveTab(_ tab: Tab) {
        stage.setTab(tab)
    }

    func setSection(_ section: String) {
        stage.setTabPayload(section)
    }

    func isSection(_ section: String) -> Bool {
        return tabPayload.first == section
    }
}
