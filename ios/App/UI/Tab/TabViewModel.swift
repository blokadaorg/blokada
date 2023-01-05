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

class TabViewModel : ObservableObject {

    private lazy var navRepo = Repos.navRepo

    @Published var activeTab: Tab = .Home
    @Published var section: Any? = nil

    // Used by SwiftUI NavigationLinks.
    // We convert them to our internal nav so that we can do it
    // manually in iPad views (built in nav is too limited there).
    @Published var navActivity: HistoryEntry? = nil { didSet {
            self.setSection(navActivity)
    }}
    @Published var navPack: Pack? = nil { didSet {
        self.setSection(navPack)
    }}
    @Published var navSetting: String? = nil { didSet {
        self.setSection(navSetting)
    }}

    private var cancellables = Set<AnyCancellable>()

    init() {
        onTabChanged()
        onSectionChanged()
    }

    private func onTabChanged() {
        navRepo.activeTabHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.activeTab = it })
        .store(in: &cancellables)
    }

    private func onSectionChanged() {
        navRepo.sectionHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.section = it })
        .store(in: &cancellables)
    }

    func setActiveTab(_ tab: Tab) {
        navRepo.setActiveTab(tab)
    }

    func setSection(_ section: Any?) {
        navRepo.setSection(section)
    }

    func isSection(_ section: String) -> Bool {
        return (self.section as? String) == section
    }

}
