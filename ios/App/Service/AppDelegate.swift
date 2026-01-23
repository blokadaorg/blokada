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
import BackgroundTasks
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands
    @Injected(\.core) private var core
    
    // Reference it so that it is created
    @Injected(\.common) private var common
    @Injected(\.stage) private var stage
    @Injected(\.url) private var url
    @Injected(\.family) private var family
    @Injected(\.safari) private var safari

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

#if canImport(FirebaseCore) && canImport(FirebaseMessaging)
        if !flutter.isFlavorFamily {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        }
#endif

        NSSetUncaughtExceptionHandler { exception in
            (UIApplication.shared.delegate as? AppDelegate)?.handleException(exception: exception)
        }

        if self.common.isRunningTests() {
            resetReposForDebug()
        } else {
            resetReposForDebug()
            startAllRepos()
        }

        common.attach(application)

        if !flutter.isFlavorFamily {
            Services.quickActions.start()
        }

        // Maybe gets the background ping (its unclear when it happens in ios)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "net.blocka.app.scheduler", using: nil) { task in
            self.handleBackgroundPing(task: task as! BGAppRefreshTask)
        }

        return true
    }

    var isTaskScheduled = false

    func scheduleBackgroundPing() {
        let request = BGAppRefreshTaskRequest(identifier: "net.blocka.app.scheduler")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 1 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            isTaskScheduled = true
            print("Scheduled background ping")
        } catch {
            print("Failed to schedule background ping: \(error)")
        }
    }

    func handleBackgroundPing(task: BGAppRefreshTask) {
        print("Got the background ping")
        isTaskScheduled = false

        // Set an expiration handler to end the task if it takes too long
        task.expirationHandler = {
            print("Background task expired")
            task.setTaskCompleted(success: false)
        }

        // Use a DispatchGroup to wait for the async job
        let group = DispatchGroup()
        group.enter()

        waitSec(howLong: 5) {
            print("Time ended for the bg ping")
            group.leave()
        }

        commands.execute(CommandName.schedulerPing)

        // Wait for the group to finish, then complete the task
        group.notify(queue: .main) {
            print("Completing background task")
            task.setTaskCompleted(success: true)
        }
    }

    func waitSec(howLong: Int, completion: @escaping () -> Void) {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(howLong)) {
            completion()
        }
    }

    func scheduleDelayedBgExecution() {
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "app.blocka.net.delayedbg") {
            // Cleanup code if the task expires
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }

        waitSec(howLong: 28) {
            print("Executing delayedbg")

            self.commands.executeWithCompletion(CommandName.schedulerPing) { result in
                // Once done, end the background task
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
                backgroundTaskID = .invalid
            }
        }
    }

    func handleException(exception: NSException) {
        let exceptionString = "Exception Name: \(exception.name)\nReason: \(exception.reason ?? "")\nUser Info: \(String(describing: exception.userInfo))"
        commands.execute(.error, exceptionString)
    }

    // Notification registration callback: success
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        common.onAppleTokenReceived(deviceToken)
#if canImport(FirebaseMessaging)
        if !flutter.isFlavorFamily {
            Messaging.messaging().apnsToken = deviceToken
        }
#endif
    }

    // Notification registration callback: failure
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        common.onAppleTokenFailed(error)
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable : Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        commands.execute(.remoteNotification)

        if let data = try? JSONSerialization.data(withJSONObject: userInfo, options: []),
           let json = String(data: data, encoding: .utf8) {
            commands.execute(.fcmEvent, json)
        }

        completionHandler(.newData)
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

    // Handle custom URL scheme (six:// etc) for linking from web extension or else (just open app)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "six" && flutter.isFlavorFamily == false {
            return true
        } else if url.scheme == "family" && flutter.isFlavorFamily {
            return true
        }
        return false
    }
}

#if canImport(FirebaseMessaging)
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken, !token.isEmpty else {
            commands.execute(.warning, "FCM registration token is empty")
            return
        }

        commands.execute(.fcmNotificationToken, token)
    }
}
#endif

// Copied from WG - not sure if important
extension AppDelegate {
    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return true
    }
    
    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return true
    }
}
