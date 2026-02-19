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
let NOTIF_WEEKLY_REFRESH = "weeklyRefresh"
let NOTIF_WEEKLY_REPORT = "weeklyReport"
let WEEKLY_REPORT_BACKGROUND_LEAD_MS = 60 * 60 * 1000

struct WeeklyReportPayload: Codable {
    let title: String?
    let body: String?
    let refreshedTitle: String?
    let refreshedBody: String?
    let backgroundLeadMs: Int?

    func toJsonString() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func refreshed() -> WeeklyReportPayload {
        WeeklyReportPayload(
            title: refreshedTitle ?? title ?? "Traffic increased refresh",
            body: refreshedBody ?? body ?? "Your traffic increased by 4% this week (bg)",
            refreshedTitle: refreshedTitle,
            refreshedBody: refreshedBody,
            backgroundLeadMs: backgroundLeadMs ?? WEEKLY_REPORT_BACKGROUND_LEAD_MS
        )
    }

    static func from(json: String?) -> WeeklyReportPayload? {
        guard let json = json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeeklyReportPayload.self, from: data)
    }
}

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
        if ProcessInfo.processInfo.isiOSAppOnMac {
            content.body = "Profile Downloaded -> Blokada -> Install..."
        } else {
            content.body = L10n.dnsprofileNotificationBody
        }
    } else if id == NOTIF_ONBOARDING_FAMILY {
        content.title = L10n.activatedHeader
        content.subtitle = L10n.dnsprofileNotificationSubtitle
        if ProcessInfo.processInfo.isiOSAppOnMac {
            content.body = "Profile Downloaded -> Blokada -> Install..."
        } else {
            content.body = L10n.dnsprofileNotificationBody.replacingOccurrences(of: "Blokada", with: "Blokada Family")
        }
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
    } else if id == NOTIF_WEEKLY_REPORT {
        guard let payload = WeeklyReportPayload.from(json: body),
              let title = payload.title, !title.isEmpty,
              let notificationBody = payload.body, !notificationBody.isEmpty else {
            content.title = ""
            content.body = ""
            content.userInfo = ["id": id]
            content.sound = .default
            return content
        }
        content.title = title
        content.body = notificationBody
    } else if id == NOTIF_WEEKLY_REFRESH {
        content.title = "Update your filters"
        content.body = "Tap to update your ad-block filters and stay safe from websites and apps that are most likely to cause you harm."
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
