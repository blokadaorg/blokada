//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

class ActivityViewModel: ObservableObject {

    private let service = ActivityService.shared
    private let sharedActions = SharedActionsService.shared

    var allEntries = [HistoryEntry]()
    @Published var entries = [HistoryEntry]()

    @Published var whitelist = [String]()
    @Published var blacklist = [String]()

    @Published var sorting = 0 {
        didSet {
            apply()
        }
    }

    @Published var filtering = 0 {
        didSet {
            apply()
        }
    }

    @Published var search = "" {
        didSet {
            apply()
        }
    }

    func fetch() {
        service.setOnUpdated { entries, whitelist, blacklist in
            onMain {
                self.whitelist = whitelist
                self.blacklist = blacklist
                self.allEntries = entries
                self.apply()
                self.objectWillChange.send()
            }
        }
    }

    func apply() {
        // Apply search term
        if search.isEmpty {
            entries = allEntries
        } else {
            entries = allEntries.filter { $0.name.range(of: search, options: .caseInsensitive) != nil }
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
        self.service.allow(entry: entry)
    }

    func unallow(_ entry: HistoryEntry) {
        self.service.unallow(entry: entry)
    }

    func deny(_ entry: HistoryEntry) {
        self.service.deny(entry: entry)
    }

    func undeny(_ entry: HistoryEntry) {
        self.service.undeny(entry: entry)
    }

    func refreshStats() {
        self.sharedActions.refreshStats()
    }
}
