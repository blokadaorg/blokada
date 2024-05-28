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

struct AccountWithKeypair {
    let account: JsonAccount
    let keypair: PlusKeypair?
}

struct JsonAccount: Codable {
    let id: String
    let active_until: String?
    let active: Bool?
    let type: String?

    func activeUntil() -> Date? {
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
