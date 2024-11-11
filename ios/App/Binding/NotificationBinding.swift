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

    content.sound = .default
    return content
}

class NotificationBinding: NotificationOps {
    private lazy var writeNotification = PassthroughSubject<String, Never>()

    private lazy var center = UNUserNotificationCenter.current()

    private var delegate: NotificationCenterDelegateHandler? = nil

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    init() {
        NotificationOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func attach(_ app: UIApplication) {
        app.registerForRemoteNotifications()

        let delegate = NotificationCenterDelegateHandler(
            writeNotification: self.writeNotification
        )
        self.center.delegate = delegate
    }

    func onAppleTokenReceived(_ appleToken: Data) {
        // Convert binary data to hex representation
        let token = appleToken.base64EncodedString()
        commands.execute(.appleNotificationToken, token)
    }

    func onAppleTokenFailed(_ err: Error) {
        commands.execute(.warning, "Failed registering for remote notifications: \(err)")
    }

    func doShow(notificationId: String, atWhen: String, body: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        //let whenDate = Date().addingTimeInterval(40)
        let whenDate = atWhen.toDate

        scheduleNotification(id: notificationId, when: whenDate, body: body)
        .sink(onFailure: { err in
            completion(.failure(err))
        }, onSuccess: {
            // Success is emitted only once the notification is triggerred
        })
        completion(.success(()))
    }
    
    func doDismissAll(completion: @escaping (Result<Void, Error>) -> Void) {
        clearAllNotifications()
        completion(.success(()))
    }

    func getPermissions() -> AnyPublisher<Granted, Error> {
        return Future<Granted, Error> { promise in
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    return promise(.success(false))
                }

                return promise(.success(true))
            }
        }
        .eraseToAnyPublisher()
    }

    func askForPermissions(which: UNAuthorizationOptions = [.badge, .alert, .sound]) -> AnyPublisher<Ignored, Error> {
        return Future<Ignored, Error> { promise in
            self.center.requestAuthorization(options: which) { granted, error in
                if let error = error {
                    return promise(.failure(error))
                }

                self.center.getNotificationSettings { settings -> Void in
                    if settings.alertSetting == .enabled {
                        return promise(.success(true))
                    } else {
                        return promise(.failure("notifications not enabled"))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    func scheduleNotification(id: String, when: Date, body: String? = nil) -> AnyPublisher<Ignored, Error> {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let date = calendar.dateComponents(
            [.year,.month,.day,.hour,.minute,.second,],
            from: when
        )

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        //let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 40, repeats: false)
        let request = UNNotificationRequest(
            identifier: id, content: mapNotificationToUser(id, body), trigger: trigger
        )

        print("Scheduling notification \(id) for: \(when.description(with: .current)), \(request)")
        print("Now is: \(Date().description(with: .current))")
        return Future<Ignored, Error> { promise in
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    print("Unauthorized for notifications")
                    return promise(.failure("unauthorized for notifications"))
                }

                self.center.add(request) { error in
                    if let error = error {
                        print("Scheduling notification failed with error: \(error)")
                        return promise(.failure(error))
                    } else {
                        return promise(.success(true))
                    }
                }
            }
        }
        .flatMap { _ in
            self.writeNotification.first { it in it == id }
            .map { _ in true }
        }

        .eraseToAnyPublisher()
    }

    func clearAllNotifications() {
        center.removeAllDeliveredNotifications()
        center.removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
}

class NotificationCenterDelegateHandler: NSObject, UNUserNotificationCenterDelegate {
    @Injected(\.commands) private var commands

    private let writeNotification: PassthroughSubject<String, Never>

    init(writeNotification: PassthroughSubject<String, Never>) {
        self.writeNotification = writeNotification
    }

    // Notification arrived (either in foreground or background)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        commands.execute(.remoteNotification)
        completionHandler(.newData)
    }

    // Called when push notification received while in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        BlockaLogger.w("Notif", "Got foreground system callback for local notification")
        writeNotification.send(notification.request.identifier)

        // No notifications while in front
        completionHandler(UNNotificationPresentationOptions(rawValue: 0))
    }

    // Chuj wie
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

}

extension Container {
    var notification: Factory<NotificationBinding> {
        self { NotificationBinding() }.singleton
    }
}
