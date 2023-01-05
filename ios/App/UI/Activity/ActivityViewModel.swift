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

class ActivityViewModel: ObservableObject {

    private let log = BlockaLogger("ActivityVM")

    private lazy var activityRepo = Repos.activityRepo
    private lazy var cloudRepo = Repos.cloudRepo

    private lazy var envService = Services.env

    private var cancellables = Set<AnyCancellable>()

    @Published var logRetention = ""
    @Published var logRetentionSelected = ""

    var allEntries = [HistoryEntry]()
    @Published var entries = [HistoryEntry]()

    @Published var whitelist = [String]()
    @Published var blacklist = [String]()

    @Published var devices = [String]()

    @Published var sorting = 0 {
        didSet {
            refreshStats()
        }
    }

    @Published var filtering = 0 {
        didSet {
            refreshStats()
        }
    }

    @Published var device = "." {
        didSet {
            refreshStats()
        }
    }

    @Published var search = "" {
        didSet {
            apply()
        }
    }
    
    init() {
        onEntriesUpdated()
        onAllowedListUpdated()
        onDeniedListUpdated()
        onActivityRetentionUpdated()
        onDevicesUpdated()
    }

    private func onEntriesUpdated() {
        activityRepo.entriesHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.allEntries = it
            self.apply()
            self.objectWillChange.send()
        })
        .store(in: &cancellables)
    }

    private func onAllowedListUpdated() {
        activityRepo.allowedListHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.whitelist = it
            self.apply()
            self.objectWillChange.send()
        })
        .store(in: &cancellables)
    }

    private func onDeniedListUpdated() {
        activityRepo.deniedListHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.blacklist = it
            self.apply()
            self.objectWillChange.send()
        })
        .store(in: &cancellables)
    }

    private func onActivityRetentionUpdated() {
        cloudRepo.activityRetentionHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.logRetention = it
        })
        .store(in: &cancellables)
    }

    private func onDevicesUpdated() {
        activityRepo.devicesHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.devices = it.filter { $0 != self.envService.deviceName }.filter { !$0.isEmpty }
            self.apply()
            self.objectWillChange.send()
        })
        .store(in: &cancellables)
    }

    func apply() {
        // Apply search term
        if search.isEmpty {
            entries = allEntries
        } else {
            entries = allEntries.filter { $0.name.range(of: search, options: .caseInsensitive) != nil }
        }
        
        // Apply device
        if device == "" {
            // All devices
            entries = entries
        } else if device == "." {
            // Current device
            entries = entries.filter { $0.device == envService.deviceName }
        } else {
            entries = entries.filter { $0.device == device }
        }

        // Apply filtering
        if filtering == 1 {
            // Blocked only
            entries = entries.filter { $0.type == .blocked }
        } else if filtering == 2 {
            // Allowed only
            entries = entries.filter { $0.type != .blocked }
        }

        // Apply sorting
        switch(sorting) {
        case 1:
            // Sorted by the number of requests
            entries = entries.sorted { $0.requests > $1.requests }
        default:
            // Sorted by recent
            entries = entries.sorted { $0.time > $1.time }
        }

    }

    func allow(_ entry: HistoryEntry) {
        activityRepo.allow(entry)
    }

    func unallow(_ entry: HistoryEntry) {
        activityRepo.unallow(entry)
    }

    func deny(_ entry: HistoryEntry) {
        activityRepo.deny(entry)
    }

    func undeny(_ entry: HistoryEntry) {
        activityRepo.undeny(entry)
    }

    private func refreshStats() {
        activityRepo.refresh()
    }

    func applyLogRetention() {
        cloudRepo.setActivityRetention(self.logRetentionSelected)
    }

}
