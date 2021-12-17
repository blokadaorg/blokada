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
let NOTIF_PAUSE = "pauseTimeout"

func mapNotificationToUser(_ id: String) -> UNMutableNotificationContent {
    if id == NOTIF_ACC_EXP {
        // TODO: check those
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationVpnExpiredHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationVpnExpiredBody
        content.sound = .default
        return content
    } else if id == "plusLeaseExpired" {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationVpnExpiredHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationVpnExpiredBody
        content.sound = .default
        return content
    } else if id == NOTIF_PAUSE {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationVpnExpiredHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationVpnExpiredBody
        content.sound = .default
        return content
    } else {
        // TODO: get also a default fallback
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationVpnExpiredHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationVpnExpiredBody
        content.sound = .default
        return content
    }
}
