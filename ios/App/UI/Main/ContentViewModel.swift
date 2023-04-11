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
import Factory

class ContentViewModel: ObservableObject {
    @Injected(\.stage) var stage

    private lazy var sheetRepo = stage
    private lazy var linkRepo = Repos.linkRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var activeSheet: StageModal? = nil
    @Published var showPauseMenu = false {
        didSet {
            self.sheetRepo.showPauseMenu(showPauseMenu)
        }
    }

    init() {
        onSheetChanged()
        onShowPauseMenuChanged()
    }

    func openLink(_ link: Link) {
        linkRepo.openLink(link)
    }

    func openLink(_ link: String) {
        linkRepo.openLink(link)
    }

    private func onSheetChanged() {
        sheetRepo.currentModal
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.activeSheet = it
        })
        .store(in: &cancellables)
    }

    private func onShowPauseMenuChanged() {
        sheetRepo.showPauseMenu
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.showPauseMenu = it
        })
        .store(in: &cancellables)
    }
}
