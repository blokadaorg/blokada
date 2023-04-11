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

class JournalItemViewModel: ObservableObject {

    private lazy var journalVM = ViewModels.journal
    private lazy var customVM = ViewModels.custom

    @Published var entry: UiJournalEntry
    @Published var whitelisted: Bool = false
    @Published var blacklisted: Bool = false

//    private let navRepo = Repos.navRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var selected: Bool = false
    private var timer: Timer? = nil

    init(entry: UiJournalEntry) {
        self.entry = entry
        self.whitelisted = customVM.whitelist.contains(entry.entry.domainName)
        self.blacklisted = customVM.blacklist.contains(entry.entry.domainName)
        startTimer()
        selected = (entry.id == journalVM.sectionStack.first?.id)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            self.objectWillChange.send()
        }
    }

    deinit {
        timer?.invalidate()
    }
}
