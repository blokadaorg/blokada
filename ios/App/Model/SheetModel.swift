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

// Represents the currently open sheet in the app.
// A sheet is any kind of modal UI popup displayed to user. Only one can be open at once.
// This includes iOS action sheets, but also dialog window, or bottom menu.
// Some sheets can open their internal sheets on top while opened, this is not tracked.
enum ActiveSheet: Identifiable {

    case Help // Help Screen (contact us)
    case Payment // Main payment screen with plans
    case Location // Location selection screen for Blokada Plus
    case Activated // A welcome showing right after purchase
    case ShowLog // Shows log with a possibliity to share
    case ShareLog // Opens OS'es file sharing with the log attached
    case Debug // Debug shortcuts and actions, not accessible in production builds
    case RateApp // Asking user to put a review
    case AdsCounter // A big total ads blocked display with option no share
    case ShareAdsCounter // Opens OS'es sharing with a short message with blocked counter

    var id: Int {
        hashValue
    }

}
