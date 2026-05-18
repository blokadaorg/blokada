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
let NOTIF_ACTIVITY_LOGGING_REMINDER = "activityLoggingReminder"
let WEEKLY_REPORT_BACKGROUND_LEAD_MS = 60 * 60 * 1000

let WEEKLY_REPORT_CATEGORY = "WEEKLY_REPORT_CATEGORY"
// Action identifiers MUST stay in sync with the Android side and with the
// Dart `notificationTapped` parser in `actor.dart` — the delegate sends
// "<notificationId>|<actionId>" to Flutter.
let WEEKLY_REPORT_ACTION_SEE_MORE = "SEE_MORE"
let WEEKLY_REPORT_ACTION_OPT_OUT = "OPT_OUT"

func registerWeeklyReportCategory() {
    let seeMore = UNNotificationAction(
        identifier: WEEKLY_REPORT_ACTION_SEE_MORE,
        title: L10n.notificationWeeklyReportActionSeeMore,
        options: [.foreground]
    )
    let optOut = UNNotificationAction(
        identifier: WEEKLY_REPORT_ACTION_OPT_OUT,
        title: L10n.notificationWeeklyReportActionOptOut,
        options: []
    )
    let category = UNNotificationCategory(
        identifier: WEEKLY_REPORT_CATEGORY,
        actions: [seeMore, optOut],
        intentIdentifiers: [],
        options: []
    )
    UNUserNotificationCenter.current().setNotificationCategories([category])
}

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
            // Belt-and-braces: the Dart caller guards on
            // `WeeklyReportEvent.isPostable` so we should never get here. If a
            // stale or malformed payload sneaks through, leave content empty
            // so the scheduling callsite can drop it.
            BlockaLogger.w("Notif", "Dropping weekly report with empty payload")
            content.title = ""
            content.body = ""
            content.userInfo = ["id": id]
            content.sound = .default
            return content
        }
        content.title = title
        content.body = notificationBody
        content.categoryIdentifier = WEEKLY_REPORT_CATEGORY
    } else if id == NOTIF_WEEKLY_REFRESH {
        content.title = "Update your filters"
        content.body = "Tap to update your ad-block filters and stay safe from websites and apps that are most likely to cause you harm."
    } else if id == NOTIF_ACTIVITY_LOGGING_REMINDER {
        content.title = "Privacy Pulse"
        content.body = body ?? "Enable activity logging to receive your weekly Privacy Pulse reports."
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

        if let id = userInfo["id"] as? String {
            StartupContext.shared.markNotificationTap(notificationId: id)
            let actionId = response.actionIdentifier
            if actionId == UNNotificationDefaultActionIdentifier {
                commands.execute(.notificationTapped, id)
            } else if actionId == UNNotificationDismissActionIdentifier {
                // user dismissed; nothing to do
            } else {
                // Custom action. Forward `id|actionId` so the Flutter command
                // signature (single string arg) carries both; Dart splits on '|'.
                commands.execute(.notificationTapped, "\(id)|\(actionId)")
            }
        } else {
            print("No custom data found.")
        }

        completionHandler()
    }

}
