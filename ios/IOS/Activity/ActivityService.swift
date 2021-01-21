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

class ActivityService {

    static var shared = ActivityService()

    private init() {
        self.loadWhitelist()
        self.loadBlacklist()
    }

    private let log = Logger("Activity")

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
                self.persistWhitelist()
            }
        }
    }

    func unallow(entry: HistoryEntry) {
        onMain {
            if self.whitelist.contains(entry.name) {
                self.whitelist.removeAll { $0 == entry.name }
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistWhitelist()
            }
        }
    }

    func deny(entry: HistoryEntry) {
        onMain {
            if !self.blacklist.contains(entry.name) {
                self.blacklist.append(entry.name)
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistBlacklist()
            }
        }
    }

    func undeny(entry: HistoryEntry) {
        onMain {
            if self.blacklist.contains(entry.name) {
                self.blacklist.removeAll { $0 == entry.name }
                self.onUpdated(self.entries, self.whitelist, self.blacklist)
                self.persistBlacklist()
            }
        }
    }

    private let destinationWhitelist = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("allow")

    static let destinationBlacklist = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: "group.net.blocka.app")!.appendingPathComponent("deny")

    private func loadWhitelist() {
        do {
            let str = try String(contentsOf: self.destinationWhitelist, encoding: .utf8)
            self.whitelist = str.components(separatedBy: "\n")
            self.log.v("Loaded \(self.whitelist.count) entries in whitelist")
        } catch {
            self.whitelist = []
        }
    }

    func persistWhitelist() {
        onMain {
            do {
                if FileManager.default.fileExists(atPath: self.destinationWhitelist.path) {
                    try FileManager.default.removeItem(at: self.destinationWhitelist)
                }

                self.log.v("Persisting \(self.whitelist.count) entries from whitelist")
                let str = self.whitelist.joined(separator: "\n")
                try str.write(to: self.destinationWhitelist, atomically: true, encoding: String.Encoding.utf8)

                self.log.v("Reloading whitelist")
                NetworkService.shared.sendMessage(msg: "reload_lists") { _, _ in }
            } catch {
                self.log.e("Could not persist whitelist".cause(error))
            }
        }
    }

    private func loadBlacklist() {
        do {
            let str = try String(contentsOf: ActivityService.destinationBlacklist, encoding: .utf8)
            self.blacklist = str.components(separatedBy: "\n")
            self.log.v("Loaded \(self.blacklist.count) entries in blacklist")
        } catch {
            self.blacklist = []
        }
    }

    func persistBlacklist() {
        onMain {
            do {
                if FileManager.default.fileExists(atPath: ActivityService.destinationBlacklist.path) {
                    try FileManager.default.removeItem(at: ActivityService.destinationBlacklist)
                }

                self.log.v("Persisting \(self.blacklist.count) entries from blacklist")
                let str = self.blacklist.joined(separator: "\n")
                try str.write(to: ActivityService.destinationBlacklist, atomically: true, encoding: String.Encoding.utf8)

                PackService.shared.reload()
            } catch {
                self.log.e("Could not persist blacklist".cause(error))
            }
        }
    }
}
