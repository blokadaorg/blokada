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
}

enum HistoryEntryType: Int, Codable {
    case whitelisted
    case blocked
    case passed
}

extension HistoryEntryType {
    static func fromTypedef(value: DNSHistoryAction) -> HistoryEntryType {
        if value == Blocked {
            return HistoryEntryType.blocked
        } else if value == Whitelisted {
            return HistoryEntryType.whitelisted
        } else {
            return HistoryEntryType.passed
        }
    }
}

extension Stats {
    func persist() {
        if let statsString = self.toJson() {
            UserDefaults.standard.set(statsString, forKey: "netx.stats")
        } else {
            NELogger.w("Could not convert stats to json")
        }
    }

    static func load() -> Stats {
        let result = UserDefaults.standard.string(forKey: "netx.stats")
        guard let stringData = result else {
            return Stats.empty()
        }

        let jsonData = stringData.data(using: .utf8)
        guard let json = jsonData else {
            NELogger.e("Failed getting stats json")
            return Stats.empty()
        }

        do {
            return try decoder.decode(Stats.self, from: json)
        } catch {
            NELogger.e("Failed decoding stats json".cause(error))
            return Stats.empty()
        }
    }

    static func empty() -> Stats {
        return Stats(allowed: 0, denied: 0, entries: [])
    }

    func combine(with stats: Stats) -> Stats {
        return Stats(
            allowed: allowed + stats.allowed,
            denied: denied + stats.denied,
            entries: stats.entries
        )
    }
}

extension Encodable {
    func toJson() -> String? {
        do {
            let jsonData = try encoder.encode(self)
            let jsonString = String(data: jsonData, encoding: .utf8)
            guard let json = jsonString else {
                NELogger.e("jsonString was nil")
                return nil
            }
            return json
        } catch {
            NELogger.e("Failed encoding to json".cause(error))
            return nil
        }
    }
}

private let blockaDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
private let decoder = initJsonDecoder()
private let encoder = initJsonEncoder()

private func initJsonDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = blockaDateFormat
    decoder.dateDecodingStrategy = .formatted(dateFormatter)
    return decoder
}

private func initJsonEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = blockaDateFormat
    encoder.dateEncodingStrategy = .formatted(dateFormatter)
    return encoder
}
