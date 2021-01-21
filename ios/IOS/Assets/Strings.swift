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
    static let account_active_forever = L10n.accountActiveForever
    static let account_type_free = "Libre"
    static let account_type_plus = "Plus"

    static func activeUntil(_ account: Account?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: userDateFormatSimple, options: 0, locale: Locale.current)!

        if account?.isActive() ?? false {
            return dateFormatter.string(for: account!.activeUntil())!
        } else {
            return account_active_forever
        }
    }

    static func accountType(_ account: Account?) -> String {
        if account?.isActive() ?? false {
            return account_type_plus
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
