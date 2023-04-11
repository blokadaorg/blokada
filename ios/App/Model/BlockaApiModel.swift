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

/**
    Blocka.net JSON API
 */

typealias AccountId = String
typealias GatewayId = String
typealias BlockaPrivateKey = String
typealias BlockaPublicKey = String
typealias ActiveUntil = Date
typealias DeviceToken = Data

struct JsonAccount: Codable {
    let id: AccountId
    let active_until: String?
    let active: Bool?
    let type: String?

    func activeUntil() -> ActiveUntil? {
        guard let active = active_until else {
            return nil
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = blockaDateFormat
        guard let date = dateFormatter.date(from: active) else {
            dateFormatter.dateFormat = blockaDateFormatNoNanos
            guard let date = dateFormatter.date(from: active) else {
                return nil
            }
            return date
        }
        return date
    }

    func isActive() -> Bool {
        return active ?? false
    }
}

extension Account: Equatable {
    static func == (lhs: Account, rhs: Account) -> Bool {
        return
            lhs.id == rhs.id &&
            lhs.activeUntil == rhs.activeUntil
    }
}


struct AccountWrapper: Decodable {
    let account: JsonAccount
}

extension Gateway {
    func niceName() -> String {
        return location.components(separatedBy: "-")
            .map { $0.capitalizingFirstLetter() }
            .joined(separator: " ")
    }
}

extension Gateway: Equatable {
    static func == (lhs: Gateway, rhs: Gateway) -> Bool {
        return
            lhs.publicKey == rhs.publicKey &&
            lhs.ipv4 == rhs.ipv4 &&
            lhs.ipv6 == rhs.ipv6 &&
            lhs.port == rhs.port
    }
}

extension Lease {
    func activeUntil() -> ActiveUntil {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = blockaDateFormat
        guard let date = dateFormatter.date(from: expires) else {
            dateFormatter.dateFormat = blockaDateFormatNoNanos
            guard let date = dateFormatter.date(from: expires) else {
                return Date(timeIntervalSince1970: 0)
            }
            return date
        }
        return date
    }

    func isActive() -> Bool {
        return activeUntil() > Date()
    }

    func niceName() -> String {
        return alias ?? String(publicKey.prefix(5))
    }
}

extension Lease: Equatable {
    static func == (lhs: Lease, rhs: Lease) -> Bool {
        return lhs.accountId == rhs.accountId
            && lhs.publicKey == rhs.publicKey
            && lhs.gatewayId == rhs.gatewayId
            && lhs.expires == rhs.expires
            && lhs.alias == rhs.alias
            && lhs.vip4 == rhs.vip4
            && lhs.vip6 == rhs.vip6
    }
}

// Used to do stuff before lease / account expires (and we may get net cutoff)
extension Date {
    func shortlyBefore() -> Date {
        let seconds = DateComponents(second: -10)
        return Calendar.current.date(byAdding: seconds, to: self) ?? self
    }
}

struct ActivityWrapper: Decodable {
    let activity: [Activity]
}

struct Activity: Decodable {
    let device_name: String
    let domain_name: String
    let action: String
    let list: String
    let timestamp: String
}

struct DeviceWrapper: Decodable {
    let device: DevicePayload
}

struct DevicePayload: Codable {
    let device_tag: String
    let lists: [String]
    let retention: String
    let paused: Bool
}

struct DeviceRequest: Codable {
    let account_id: AccountId
    let lists: [String]?
    let retention: String?
    let paused: Bool?
}

struct Blocklist: Decodable {
    let id: String
    let name: String
    let managed: Bool
    let is_allowlist: Bool
}

// Our internal version of the Blocklist
struct MappedBlocklist: Decodable {
    let id: String
    let packId: String
    let packConfig: String
}

struct BlocklistWrapper: Decodable {
    let lists: [Blocklist]
}

struct ExceptionWrapper: Decodable {
    let customlist: [CustomListEntry]
}

struct CustomListEntry: Decodable {
    let domain_name: String
    let action: String
}

extension CustomListEntry: Equatable {
    static func == (lhs: CustomListEntry, rhs: CustomListEntry) -> Bool {
        return
            lhs.domain_name == rhs.domain_name &&
            lhs.action == rhs.action
    }
}


struct CustomListRequest: Codable {
    let account_id: AccountId
    let domain_name: String
    let action: String
}

struct CounterStats: Decodable {
    let total_allowed: String
    let total_blocked: String
}

struct AppleCheckoutRequest: Codable {
    let account_id: AccountId
    let receipt: String
}

struct AppleDeviceTokenRequest: Codable {
    let account_id: AccountId
    let public_key: BlockaPublicKey
    let device_token: AppleToken
}

typealias AppleToken = Data
