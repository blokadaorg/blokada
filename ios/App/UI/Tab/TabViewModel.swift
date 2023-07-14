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

    @Published var homeSection = [String]()
    @Published var journalSection = [String]()
    @Published var deckSection = [String]()
    @Published var settingsSection = [String]()

    @Published var showNavBar = true

    private var cancellables = Set<AnyCancellable>()

    init() {
        onTabChanged()
        onTabPayloadChanged()
        onShowNavbar()
    }

    private func onTabChanged() {
        stage.activeTab
        //.receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.activeTab = it
        })
        .store(in: &cancellables)
    }

    private func onTabPayloadChanged() {
        stage.tabPayload
        //.receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.setEmptySections()
            if let it = it {
                // This is necessary swiftui is weird trust me
                if self.activeTab == .Home {
                    self.homeSection = [it]
                } else if self.activeTab == .Activity {
                    self.journalSection = [it]
                } else if self.activeTab == .Advanced {
                    self.deckSection = [it]
                } else if self.activeTab == .Settings {
                    self.settingsSection = [it]
                }
            }
        })
        .store(in: &cancellables)
    }

    private func setEmptySections() {
        self.homeSection = []
        self.journalSection = []
        self.deckSection = []
        self.settingsSection = []
    }

    private func onShowNavbar() {
        stage.showNavbar
        //.receive(on: RunLoop.main)
        .sink(onValue: { it in self.showNavBar = it })
        .store(in: &cancellables)
    }

    func setActiveTab(_ tab: Tab) {
        stage.setTab(tab)
    }

    func setSection(_ section: String) {
        stage.setTabPayload(section)
    }

    // This is only for settings
    func isSection(_ section: String) -> Bool {
        if activeTab == .Settings {
            return settingsSection.first == section
        }
        return false
    }
}
