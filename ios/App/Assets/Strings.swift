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

class Strings {
    static let account_type_free = "Libre"
    static let account_type_cloud = "Cloud"
    static let account_type_plus = "Plus"

    static func activeUntil(_ account: JsonAccount?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: userDateFormatSimple, options: 0, locale: Locale.current)!

        if let account = account, account.isActive() {
            return dateFormatter.string(for: account.activeUntil()) ?? ""
        } else {
            return ""
        }
    }

    static func accountType(_ account: JsonAccount?) -> String {
        if account?.isActive() ?? false {
            if account?.type == "cloud" {
                return account_type_cloud
            } else {
                return account_type_plus
            }
        } else {
            return account_type_free
        }
    }

    static func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: userDateFormatSimple, options: 0, locale: Locale.current)!

        return dateFormatter.string(for: date)!
    }
}
