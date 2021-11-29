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
import UIKit

class ActivityRepository {

    static var shared = ActivityRepository()

    private init() {
        self.loadExceptions()
    }

    private let log = Logger("Activity")
    private let api = BlockaApiService.shared

    private let hardcodedHistory = [
        HistoryEntry(name: "doubleclick.com", type: .blocked, time: Date(timeIntervalSinceNow: -5), requests: 45),
        HistoryEntry(name: "google.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -7), requests: 1),
        HistoryEntry(name: "example.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -8), requests: 1),
        HistoryEntry(name: "a.example.com", type: .blocked, time: Date(timeIntervalSinceNow: -12), requests: 3),
        HistoryEntry(name: "b.example.com", type: .blocked, time: Date(timeIntervalSinceNow: -12), requests: 2),
        HistoryEntry(name: "a.doubleclick.com", type: .blocked, time: Date(timeIntervalSinceNow: -15), requests: 42),
        HistoryEntry(name: "b.doubleclick.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -30), requests: 1),
        HistoryEntry(name: "c.doubleclick.com", type: .blocked, time: Date(timeIntervalSinceNow: -3600), requests: 1),
        HistoryEntry(name: "graph.facebook.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -3689), requests: 1),
        HistoryEntry(name: "aa.facebook.com", type: .blocked, time: Date(timeIntervalSinceNow: -3789), requests: 3),
        HistoryEntry(name: "bb.facebook.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -3799), requests: 4),
        HistoryEntry(name: "cc.facebook.com", type: .blocked, time: Date(timeIntervalSinceNow: -3800), requests: 2),
        HistoryEntry(name: "1.something.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -3900), requests: 12),
        HistoryEntry(name: "2.something.com", type: .blocked, time: Date(timeIntervalSinceNow: -10000), requests: 6),
        HistoryEntry(name: "3.something.com", type: .whitelisted, time: Date(timeIntervalSinceNow: -10001), requests: 1)
    ]

    private let hardcodedWhitelist = [
        "google.com",
        "example.com",
        "b.doubleclick.com",
        "graph.facebook.com",
        "bb.facebook.com",
        "1.something.com",
        "3.something.com"
    ]

    private var entries = [HistoryEntry]()
    private var whitelist = [String]()
    private var blacklist = [String]()

    private var onUpdated = { (entries: [HistoryEntry], whitelist: [String], blacklist: [String]) in }

    func setOnUpdated(callback: @escaping ([HistoryEntry], [String], [String]) -> Void) {
        onMain {
            self.onUpdated = callback
            callback(self.entries, self.whitelist, self.blacklist)
        }
    }

    func setEntries(entries: [HistoryEntry]) {
        onMain {
            if !entries.isEmpty {
                self.log.v("History entries set: \(entries.count)")
                self.entries = entries
            }

            self.onUpdated(self.entries, self.whitelist, self.blacklist)
        }
    }

    func allow(entry: HistoryEntry) {
        onMain {
            if !self.whitelist.contains(entry.name) {
                self.whitelist.append(entry.name)
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistException(entry.name, "allow")
            }
        }
    }

    func unallow(entry: HistoryEntry) {
        onMain {
            if self.whitelist.contains(entry.name) {
                self.whitelist.removeAll { $0 == entry.name }
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistException(entry.name, "fallthrough")
            }
        }
    }

    func deny(entry: HistoryEntry) {
        onMain {
            if !self.blacklist.contains(entry.name) {
                self.blacklist.append(entry.name)
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistException(entry.name, "block")
            }
        }
    }

    func undeny(entry: HistoryEntry) {
        onMain {
            if self.blacklist.contains(entry.name) {
                self.blacklist.removeAll { $0 == entry.name }
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistException(entry.name, "fallthrough")
            }
        }
    }

    private func loadExceptions() {
        onBackground {
            self.api.getCurrentBlockingExceptions { error, exceptions in
                guard error == nil, let exceptions = exceptions else {
                    return self.log.w("loadExceptions: could not fetch exceptions".cause(error))
                }

                onMain {
                    self.whitelist = exceptions.filter({
                        exception in exception.action == "allow"
                    }).map({ exception in exception.domain_name })

                    self.blacklist = exceptions.filter({
                        exception in exception.action == "block"
                    }).map({ exception in exception.domain_name })
                }
            }
        }
    }

    func persistException(_ name: String, _ action: String) {
        onBackground {
            self.api.postBlockingException(request: BlockingExceptionRequest(
                account_id: Config.shared.accountId(),
                domain_name: name,
                action: action
            ), method: action == "fallthrough" ? "DELETE" : "POST") { error, _ in
                guard error == nil else {
                    return self.log.w("persistException: could not persist exception".cause(error))
                }
            }
        }
    }

}
