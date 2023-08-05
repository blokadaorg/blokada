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

class JournalViewModel: ObservableObject {
    @Injected(\.env) private var env
    @Injected(\.cloud) private var cloud
    @Injected(\.journal) private var journal
    @Injected(\.stage) private var stage
    @Injected(\.commands) private var commands

    @Published var sectionStack = [UiJournalEntry]()

    private var cancellables = Set<AnyCancellable>()

    @Published var logRetention = ""
    @Published var logRetentionSelected = ""

    @Published var entries = [UiJournalEntry]()
    @Published var devices = [String]()

    @Published var sorting = 0 {
        didSet {
            if sorting == oldValue {
                return
            }

            if sorting == 0 {
                self.commands.execute(.sortNewest)
            } else {
                self.commands.execute(.sortCount)
            }
        }
    }

    @Published var filtering = 0 {
        didSet {
            if filtering == oldValue {
                return
            }

            if filtering == 1 {
                self.commands.execute(.filter, "blocked")
            } else if filtering == 2 {
                self.commands.execute(.filter, "passed")
            } else {
                self.commands.execute(.filter, "all")
            }
        }
    }

    @Published var device = "" {
        didSet {
            if device == oldValue {
                return
            }

            if device == "." {
                self.commands.execute(.filterDevice, self.cloud.deviceAlias)
            } else {
                self.commands.execute(.filterDevice, device)
            }
        }
    }

    @Published var search = "" {
        didSet {
            if search == oldValue {
                return
            }

            updateSearch()
        }
    }

    init() {
        journal.onEntries = { it in
            self.entries = it
            self.objectWillChange.send()
        }

        journal.onFilter = { it in
            if self.device != it.deviceName {
                if it.deviceName == self.cloud.deviceAlias {
                    if self.device != "." {
                        self.device = "."
                    }
                } else {
                    self.device = it.deviceName
                }
            }

            if self.search != it.searchQuery {
                self.search = it.searchQuery
            }
            
            if it.showOnly == .blocked {
                self.filtering = 1
            } else if it.showOnly == .passed {
                self.filtering = 2
            } else {
                self.filtering = 0
            }
            
            if it.sortNewestFirst {
                self.sorting = 0
            } else {
                self.sorting = 1
            }
        }
        
        journal.onDevices = { it in
            self.devices = it.filter({ it in
                // Dont show our own device name on the list
                it != self.cloud.deviceAlias
            })
            self.objectWillChange.send()
        }

        onActivityRetentionUpdated()
        onTabPayloadChanged()
    }

    func applyLogRetention() {
        cloud.setActivityRetention(self.logRetentionSelected)
    }

    func byId(_ id: String) -> UiJournalEntry? {
        return entries.first { it in
            it.id == id
        }
    }

    private func onActivityRetentionUpdated() {
        cloud.activityRetentionHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.logRetention = it
        })
        .store(in: &cancellables)
    }

    private func onTabPayloadChanged() {
        stage.tabPayload
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            if let it = it, let entry = self.byId(it) {
                self.sectionStack = [entry]
            } else {
                self.sectionStack = []
            }
        })
        .store(in: &cancellables)
    }

    var timer: Timer?
    private func updateSearch() {
        // Timer to not cause a loop
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.commands.execute(.search, self.search)
        }
    }
}
