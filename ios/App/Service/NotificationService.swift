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
import Combine

// NotificationService will display user notification in the future, even when the app is
// in the background. We use it for notifying users, but also as a mechanism to complete
// some actions that need to happen in the background (through the user). The reason is
// that the background processing api seemed very unreliable on iOS and we don't use it.
class NotificationService {

    private lazy var writeNotification = PassthroughSubject<String, Never>()

    private lazy var center = UNUserNotificationCenter.current()

    private var delegate: NotificationCenterDelegateHandler? = nil

    func registerNotifications() {
        let delegate = NotificationCenterDelegateHandler(
            writeNotification: self.writeNotification
        )
        self.center.delegate = delegate
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

    func scheduleNotification(id: String, when: Date) -> AnyPublisher<Ignored, Error> {
        let date = Calendar.current.dateComponents(
            [.year,.month,.day,.hour,.minute,.second,],
            from: when
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: false)
        let request = UNNotificationRequest(
            identifier: id, content: mapNotificationToUser(id), trigger: trigger
        )

        return Future<Ignored, Error> { promise in
            self.center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else {
                    return promise(.failure("unauthorized for notifications"))
                }

                self.center.add(request) { error in
                    if let error = error {
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
    }

}

class NotificationCenterDelegateHandler: NSObject, UNUserNotificationCenterDelegate {

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
        // We currently only send push notifications when Lease/Account is about to expire
        // I haven't tested this, but let's try to invoke the usual flow and hope it works.
        // Normally (for foreground notif) this would execute timer expiration callback.
        // So in case of NOTIF_ACC_EXP, it will expire account and deactivate everything.
        BlockaLogger.w("Notif", "Received push notification, marking NOTIF_ACC_EXP")
        self.writeNotification.send(NOTIF_ACC_EXP)
        completionHandler(.newData)
    }

    // Called when push notification received while in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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
