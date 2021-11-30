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
typealias PrivateKey = String
typealias PublicKey = String
typealias ActiveUntil = Date
typealias DeviceToken = Data

struct Account: Codable {
    let id: AccountId
    let active_until: String?
    let active: Bool?
    let type: String?

    func activeUntil() -> ActiveUntil {
        guard let active = active_until else {
            return Date(timeIntervalSince1970: 0)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = blockaDateFormat
        guard let date = dateFormatter.date(from: active) else {
            dateFormatter.dateFormat = blockaDateFormatNoNanos
            guard let date = dateFormatter.date(from: active) else {
                return Date(timeIntervalSince1970: 0)
            }
            return date
        }
        return date
    }

    func isActive() -> Bool {
        return active ?? (activeUntil() > Date())
    }
}

struct AccountWrapper: Decodable {
    let account: Account
}

struct Gateway: Codable {
    let public_key: GatewayId
    let region: String
    let location: String
    let resource_usage_percent: Int
    let ipv4: String
    let ipv6: String
    let port: Int
    //let expires: ActiveUntil
    let tags: [String]?
    let country: String?

    func niceName() -> String {
        return location.components(separatedBy: "-")
            .map { $0.capitalizingFirstLetter() }
            .joined(separator: " ")
    }
}

struct Gateways: Decodable {
    let gateways: [Gateway]
}

struct Lease: Codable, Identifiable {
    let id = UUID()
    let account_id: AccountId
    let public_key: PublicKey
    let gateway_id: GatewayId
    let expires: String
    let alias: String?
    let vip4: String
    let vip6: String

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
        return alias ?? String(public_key.prefix(5))
    }

    func isMe() -> Bool {
        return public_key == Config.shared.publicKey()
    }
}

struct LeaseWrapper: Decodable {
    let lease: Lease
    let alias: String?
}

struct Leases: Decodable {
    let leases: [Lease]
}

struct LeaseRequest: Codable {
    let account_id: AccountId
    let public_key: PublicKey
    let gateway_id: GatewayId
    let alias: String?
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
    let customlist: [BlockingException]
}

struct BlockingException: Decodable {
    let domain_name: String
    let action: String
}

struct BlockingExceptionRequest: Codable {
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
    let public_key: PublicKey
    let device_token: Data
}
