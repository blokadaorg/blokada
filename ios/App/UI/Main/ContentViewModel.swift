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

enum ShareContent: Identifiable {
    case text(String)
    case url(URL)
    
    // Using a UUID ensures uniqueness
    var id: UUID { UUID() }
    
    /// Extracts the underlying value to use in the share sheet.
    var item: Any {
        switch self {
        case .text(let string):
            return string
        case .url(let url):
            return url
        }
    }
}

class ContentViewModel: ObservableObject {
    @Injected(\.stage) var stage
    @Injected(\.core) var core
    @Injected(\.common) var common
    @Injected(\.family) var family

    private lazy var linkRepo = Repos.linkRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var activeSheet: StageModal? = nil
    @Published var showPauseMenu = false {
        didSet {
            self.stage.showPauseMenu(showPauseMenu)
        }
    }

    @Published var shareContent: ShareContent? = nil

    init() {
        onSheetChanged()
        onShowPauseMenuChanged()
        onShareLog()
        onShareUrl()
        onShareText()
    }

    func openLink(_ link: String) {
        linkRepo.openLink(link)
    }

    private func onSheetChanged() {
        stage.currentModal
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.activeSheet = it
        })
        .store(in: &cancellables)
    }

    private func onShowPauseMenuChanged() {
        stage.showPauseMenu
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.showPauseMenu = it
        })
        .store(in: &cancellables)
    }

    private func onShareLog() {
        core.shareLog
        .compactMap { $0 }
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.shareContent = .url(it)
        })
        .store(in: &cancellables)
    }

    private func onShareUrl() {
        family.shareUrl
        .compactMap { $0 }
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.shareContent = .url(it)
        })
        .store(in: &cancellables)
    }

    private func onShareText() {
        common.shareText
        .compactMap { $0 }
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.shareContent = .text(it)
        })
        .store(in: &cancellables)
    }
}
