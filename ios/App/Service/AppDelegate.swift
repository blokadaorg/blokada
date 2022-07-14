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
import Flutter

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private var token: AppleTokenService?
    private var quick: QuickActionsService?

    lazy var flutterEngine = FlutterEngine(name: "common")

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

        let log = Logger("")
        log.w("*** ******************* ***")
        log.w("*** BLOKADA IOS STARTED ***")
        log.w("*** ******************* ***")
        log.v(Services.env.userAgent())
        log.v("Time now: \(Date().description(with: .current))")

        flutterEngine.run()

        if Services.env.isRunningTests {
            resetReposForDebug()
        } else {
            resetReposForDebug()
            startAllRepos()
        }

        Repos.stageRepo.onCreate()
        token = AppleTokenService(application)

        Services.quickActions.start()

        // A bunch of lazy, noone else refs this (early enough).
        let rate = Services.rate
        let payment = Repos.paymentRepo

        return true
    }

    // Notification registration callback: success
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        token?.onAppleTokenReceived(deviceToken)
    }

    // Notification registration callback: failure
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        token?.onAppleTokenFailed(error)
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
        Logger.v("Main", "Application will terminate")
        Repos.stageRepo.onDestroy()
    }

}
