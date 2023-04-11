//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine

struct UiJournalEntry {
    let id = UUID().uuidString
    let entry: JournalEntry
    let time: Date
}

extension UiJournalEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(entry.deviceName)
        hasher.combine(entry.type)
        hasher.combine(entry.deviceName)
    }
}

extension UiJournalEntry: Equatable {
    static func == (lhs: UiJournalEntry, rhs: UiJournalEntry) -> Bool {
        lhs.entry.domainName == rhs.entry.domainName
            && lhs.entry.type == rhs.entry.type
            && lhs.entry.deviceName == rhs.entry.deviceName
    }
}

class JournalBinding: JournalOps {
    var onEntries: ([UiJournalEntry]) -> Void = { _ in }
    var onFilter: (JournalFilter) -> Void = { _ in }
    var onDevices: ([String]) -> Void = { _ in }

    @Injected(\.flutter) private var flutter

    init() {
        JournalOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doReplaceEntries(entries: [JournalEntry], completion: @escaping (Result<Void, Error>) -> Void) {
        onEntries(entries.map({ it in
            UiJournalEntry(entry: it, time: it.time.toDate)
        }))
        completion(.success(()))
    }
    
    func doFilterChanged(filter: JournalFilter, completion: @escaping (Result<Void, Error>) -> Void) {
        onFilter(filter)
        completion(.success(()))
    }

    func doDevicesChanged(devices: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        onDevices(devices)
        completion(.success(()))
    }

    func doHistoricEntriesAvailable(entries: [JournalEntry], completion: @escaping (Result<Void, Error>) -> Void) {
        // TODO
        completion(.success(()))
    }
}

extension Container {
    var journal: Factory<JournalBinding> {
        self { JournalBinding() }.singleton
    }
}
