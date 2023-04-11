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
let NOTIF_ONBOARDING = "onboardingDnsAdvice"

func mapNotificationToUser(_ id: String) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()

    if id == NOTIF_ACC_EXP {
        content.title = L10n.notificationAccHeader
        content.subtitle = L10n.notificationAccSubtitle
        content.body = L10n.notificationAccBody
        content.sound = .default
    } else if id == NOTIF_LEASE_EXP {
        content.title = L10n.notificationLeaseHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationGenericBody
        content.sound = .default
    } else if id == NOTIF_PAUSE {
        content.title = L10n.notificationPauseHeader
        content.subtitle = L10n.notificationPauseSubtitle
        content.body = L10n.notificationPauseBody
        content.sound = .default
    } else if id == NOTIF_ONBOARDING {
        content.title = L10n.activatedHeader
        content.subtitle = L10n.dnsprofileNotificationSubtitle
        content.body = L10n.dnsprofileNotificationBody
        content.sound = .default
    } else {
        content.title = L10n.notificationGenericHeader
        content.subtitle = L10n.notificationGenericSubtitle
        content.body = L10n.notificationGenericBody
        content.sound = .default
    }

    return content
}
