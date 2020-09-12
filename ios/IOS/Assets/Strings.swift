//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
