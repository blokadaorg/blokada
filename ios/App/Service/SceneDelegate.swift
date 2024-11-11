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
import SwiftUI
import Factory

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let homeVM = ViewModels.home
    private let tabVM = ViewModels.tab

    @Injected(\.stage) private var foreground
    @Injected(\.commands) private var commands

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let controller = ContentHostingController(rootView:
                ContentView()
            )

            controller.onTransitioning = { (transitioning: Bool) in
                if transitioning {
                    self.homeVM.showSplash = transitioning
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.homeVM.showSplash = false
                    }
                }
            }

            window.rootViewController = controller
            self.window = window
            Services.dialog.setController(controller)

            window.makeKeyAndVisible()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.homeVM.showSplash = false
        }
        
        
        // Handle universal links
        // Currently only the link_device url is supported
        guard let userActivity = connectionOptions.userActivities.first,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return
        }

        commands.execute(.url, incomingURL.absoluteString)
    }
    
    func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        guard let incomingURL = userActivity.webpageURL else {
            return
        }

        commands.execute(.url, incomingURL.absoluteString)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        homeVM.hideContent = false
        foreground.onForeground(true)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).`

        // Close the kb when leaving to bg
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        homeVM.hideContent = true
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        foreground.onForeground(false)

        // Whenver leaving bg, schedule the ping from OS after some time
        // It's designed to help the scheduled tasks to execute, but it's probably
        // not doing much. iOS background execution is very unpredictable.
        // However we should not need it as long as the app is running in the bg.
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.scheduleBackgroundPing()
            appDelegate.scheduleDelayedBgExecution()
        }
    }

    // Quick action selected by user
    func windowScene(
        _ scene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Services.quickActions.onQuickAction(shortcutItem.type)
    }
}
