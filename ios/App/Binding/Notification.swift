//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine
import UIKit
import UserNotifications

let NOTIF_ACC_EXP = "accountExpired"
let NOTIF_LEASE_EXP = "plusLeaseExpired"
let NOTIF_PAUSE = "pauseTimeout"
let NOTIF_ONBOARDING = "onboardingDnsAdvice"
let NOTIF_ONBOARDING_FAMILY = "onboardingDnsAdviceFamily"
let NOTIF_ACC_EXP_FAMILY = "accountExpiredFamily"
let NOTIF_SUPPORT_NEWMSG = "supportNewMessage"

func mapNotificationToUser(_ id: String, _ body: String?) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    content.badge = NSNumber(value: 0)

    if id == NOTIF_ACC_EXP {
        content.title = L10n.notificationAccHeader
        content.subtitle = L10n.notificationAccSubtitle
        content.body = L10n.notificationAccBody
    } else if id == NOTIF_LEASE_EXP {
        content.title = L10n.notificationLeaseHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationGenericBody
    } else if id == NOTIF_PAUSE {
        content.title = L10n.notificationPauseHeader
        content.subtitle = L10n.notificationPauseSubtitle
        content.body = L10n.notificationPauseBody
    } else if id == NOTIF_ONBOARDING {
        content.title = L10n.activatedHeader
        content.subtitle = L10n.dnsprofileNotificationSubtitle
        content.body = L10n.dnsprofileNotificationBody
    } else if id == NOTIF_ONBOARDING_FAMILY {
        content.title = L10n.activatedHeader
        content.subtitle = L10n.dnsprofileNotificationSubtitle
        content.body = L10n.dnsprofileNotificationBody.replacingOccurrences(of: "Blokada", with: "Blokada Family")
    } else if id == NOTIF_ACC_EXP_FAMILY {
        content.title = L10n.notificationAccHeader
        content.subtitle = L10n.familyNotificationSubtitle
        content.body = L10n.notificationAccBody
    } else if id == NOTIF_SUPPORT_NEWMSG {
        content.title = "New message"
        //content.subtitle = "You got a message from the support"
        content.body = "Tap to see the reply"
        if let body = body, !body.isEmpty {
            content.body = body.count > 32 ? body.prefix(32) + "..." : body
        }
        content.badge = NSNumber(value: 1)
    } else {
        content.title = L10n.notificationGenericHeader
        content.subtitle = L10n.notificationGenericSubtitle
        content.body = L10n.notificationGenericBody
    }

    content.userInfo = ["id": id]
    content.sound = .default
    return content
}

class NotificationCenterDelegateHandler: NSObject, UNUserNotificationCenterDelegate {
    @Injected(\.commands) private var commands

    private let writeNotification: PassthroughSubject<String, Never>

    init(writeNotification: PassthroughSubject<String, Never>) {
        self.writeNotification = writeNotification
    }

    // Push notification arrived (either in foreground or background)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        commands.execute(.remoteNotification)
        completionHandler(.newData)
    }

    // Called when a notification received while in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        BlockaLogger.w("Notif", "Got foreground system callback for a notification")
        writeNotification.send(notification.request.identifier)

        // No notifications while in front
        completionHandler(UNNotificationPresentationOptions(rawValue: 0))
    }

    // Callen when notification is clicked by user
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        print("Notification tapped with info: \(userInfo)")
        if let id = userInfo["id"] as? String {
            commands.execute(.notificationTapped, id)
        } else {
            print("No custom data found.")
        }

        completionHandler()
    }

}
