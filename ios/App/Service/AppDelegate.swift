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

import UIKit
import Factory

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    @Injected(\.env) private var env
    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands
    
    // Reference it so that it is created
    @Injected(\.logger) private var tracer
    @Injected(\.notification) private var notification
    @Injected(\.payment) private var payment
    @Injected(\.http) private var http
    @Injected(\.persistence) private var persistence
    @Injected(\.stage) private var stage
    @Injected(\.stats) private var stats
    @Injected(\.rate) private var rate
    @Injected(\.link) private var link
    @Injected(\.url) private var url

    private var deps = FlavorDeps()

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LoggerSaver.cleanup()

        NSSetUncaughtExceptionHandler { exception in
            (UIApplication.shared.delegate as? AppDelegate)?.handleException(exception: exception)
        }

        if self.env.isRunningTests() {
            resetReposForDebug()
        } else {
            resetReposForDebug()
            startAllRepos()
        }

        notification.attach(application)

        if !flutter.isFlavorFamily {
            Services.quickActions.start()
        }

        // A bunch of lazy, noone else refs this (early enough).
        payment.startObservingPayments()

        return true
    }

    func handleException(exception: NSException) {
        let exceptionString = "Exception Name: \(exception.name)\nReason: \(exception.reason ?? "")\nUser Info: \(String(describing: exception.userInfo))"
        commands.execute(.fatal, exceptionString)
    }

    // Notification registration callback: success
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        notification.onAppleTokenReceived(deviceToken)
    }

    // Notification registration callback: failure
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        notification.onAppleTokenFailed(error)
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Use the methods in SceneDelegate instead
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use the methods in SceneDelegate instead
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Use the methods in SceneDelegate instead
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Use the methods in SceneDelegate instead
    }

    func applicationWillTerminate(_ application: UIApplication) {
        BlockaLogger.v("Main", "Application will terminate")
        payment.stopObservingPayments()
    }

    // Handle universal links TODO: Also in SceneDelegate
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
    {
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return false
        }

        commands.execute(.url, incomingURL.absoluteString)
        return true
    }

}

// Copied from WG - not sure if important
extension AppDelegate {
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return true
    }
}
