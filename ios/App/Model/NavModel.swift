//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation

enum Tab {
    case Home
    case Activity
    case Advanced
    case Settings
}

func mapTabIdToTab(_ tabId: String) -> Tab {
    switch (tabId) {
        case "home": return Tab.Home
        case "activity": return Tab.Activity
        case "packs": return Tab.Advanced
        default: return Tab.Settings
    }
}

protocol Navigable: Hashable {
    
}
