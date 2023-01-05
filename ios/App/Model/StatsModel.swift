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

struct Stats: Codable {
    let allowed: UInt64
    let denied: UInt64
    let entries: [HistoryEntry]
}

struct HistoryEntry: Codable {
    let name: String
    let type: HistoryEntryType
    let time: Date
    let requests: UInt64
    let device: String
    let list: String?
}

enum HistoryEntryType: Int, Codable {
    case whitelisted
    case blocked
    case passed
}

extension HistoryEntry: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(type)
        hasher.combine(device)
    }
}

extension HistoryEntry: Equatable {
    static func == (lhs: HistoryEntry, rhs: HistoryEntry) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type && lhs.device == rhs.device
    }
}
