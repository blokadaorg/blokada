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

enum Tab: String {
    case Home
    case Activity
    case Advanced
    case Settings
}

func mapTabIdToTab(_ tabId: String) -> Tab {
    switch (tabId) {
        case "settings": return Tab.Settings
        case "activity": return Tab.Activity
        case "advanced": return Tab.Advanced
        default: return Tab.Home
    }
}

protocol Navigable: Hashable {
    
}
