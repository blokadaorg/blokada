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
