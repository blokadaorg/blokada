//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UserNotifications
import UIKit

class NotificationService {

    static let shared = NotificationService()

    private let log = Logger("Notif")
    private let notifications = UNUserNotificationCenter.current()
    private let accountExpiredId = "accountExpired"
    private let api = BlockaApiService.shared
    private let expiration = ExpirationService.shared

    private init() {}

    func registerNotifications(for application: UIApplication) {
        application.registerForRemoteNotifications()
        notifications.delegate = application.delegate as! AppDelegate
    }

    func askForPermissions(which: UNAuthorizationOptions = [.badge, .alert, .sound]) {
        notifications.requestAuthorization(options: which) { granted, error in
            if let error = error {
                return self.log.w("Failed requesting notifications permission".cause(error))
            }
            self.notifications.getNotificationSettings { settings in
                if settings.alertSetting == .enabled {
                    self.log.v("Authorized notification with alerts enabled")
                }
            }
        }
    }

    func didRegisterForNotificationsWithDeviceToken(deviceToken: Data) {
        self.log.v("Registered notification token")
        Config.shared.setDeviceToken(deviceToken)
    }

    func didFailToRegisterForNotificationsWithError(error: Error) {
        log.e("Failed to register for remote notifications".cause(error))
    }

    func didReceiveRemoteNotification(userInfo: [AnyHashable : Any], completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        log.v("Received available content notification, update scheduled expiry notifcation")

        self.checkLease(ok: { newData in
            if newData {
                completionHandler(.newData)
            } else {
                completionHandler(.noData)
            }
        }, fail: { error in
            completionHandler(.failed)
        })
    }

    func scheduleExpiredNotification(when: ActiveUntil) {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationVpnExpiredHeader
        content.subtitle = L10n.notificationVpnExpiredSubtitle
        content.body = L10n.notificationVpnExpiredBody
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second,], from: when)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(identifier: accountExpiredId,
                    content: content, trigger: trigger)

        notifications.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            self.notifications.add(request) { error in
                if let error = error {
                    return self.log.w("Failed sending notification".cause(error))
                }

                self.log.v("Notification scheduled at \(when)")
            }
        }
    }

    func clearNotification() {
        notifications.removeAllDeliveredNotifications()
        notifications.removeAllPendingNotificationRequests()
        self.log.v("Notification cleared")
    }

    func checkLease(ok: @escaping Ok<Bool>, fail: @escaping Fail) {
        onBackground {
            self.api.getCurrentLease { error, lease in
                if let error = error {
                    self.log.e("Failed getting current lease".cause(error))
                    return fail(error)
                } else if let lease = lease {
                    self.scheduleExpiredNotification(when: lease.activeUntil())
                    self.expiration.update(lease)
                    return ok(true)
                } else {
                    return ok(false)
                }
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        print(response.notification.request.content.userInfo)
        completionHandler()
    }

    // Called when push notification received while in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {

        NotificationService.shared.checkLease(ok: { newData in }, fail: { error in })

        // No notifications while in front
        completionHandler(UNNotificationPresentationOptions(rawValue: 0))
    }

}
