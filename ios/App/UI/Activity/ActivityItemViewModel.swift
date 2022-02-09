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

class ActivityItemViewModel: ObservableObject {

    @Published var entry: HistoryEntry
    @Published var whitelisted: Bool
    @Published var blacklisted: Bool

    private var vm = ViewModels.activity
    private let navRepo = Repos.navRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var selected: Bool = false
    private var timer: Timer? = nil

    init(entry: HistoryEntry) {
        self.entry = entry
        self.whitelisted = vm.whitelist.contains(entry.name)
        self.blacklisted = vm.blacklist.contains(entry.name)
        startTimer()
        onNavChanged()
    }

    private func onNavChanged() {
        navRepo.sectionHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.selected = (it as? HistoryEntry) == self.entry
        })
        .store(in: &cancellables)
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
