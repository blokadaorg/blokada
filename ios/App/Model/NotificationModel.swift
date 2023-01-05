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
import UserNotifications

let NOTIF_ACC_EXP = "accountExpired"
let NOTIF_LEASE_EXP = "plusLeaseExpired"
let NOTIF_PAUSE = "pauseTimeout"

func mapNotificationToUser(_ id: String) -> UNMutableNotificationContent {
    if id == NOTIF_ACC_EXP {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationAccHeader
        content.subtitle = L10n.notificationAccSubtitle
        content.body = L10n.notificationAccBody
        content.sound = .default
        return content
    } else if id == NOTIF_LEASE_EXP {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationLeaseHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationGenericBody
        content.sound = .default
        return content
    } else if id == NOTIF_PAUSE {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationPauseHeader
        content.subtitle = L10n.notificationPauseSubtitle
        content.body = L10n.notificationPauseBody
        content.sound = .default
        return content
    } else {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationGenericHeader
        content.subtitle = L10n.notificationGenericSubtitle
        content.body = L10n.notificationGenericBody
        content.sound = .default
        return content
    }
}
