//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation

enum AccountType {
    case Libre
    case Cloud
    case Plus
}

func mapAccountType(_ accountType: String?) -> AccountType {
    switch (accountType) {
        case "cloud": return AccountType.Cloud
        case "plus": return AccountType.Plus
        default: return AccountType.Libre
    }
}

extension AccountType {

    func isActive() -> Bool {
        return self == .Cloud || self == .Plus
    }

    func toString() -> String {
        return "\(self)"
    }

}

enum AppState {
    case Deactivated
    case Paused
    case Activated
    case New
}
