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

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private let homeVM = HomeViewModel()
    private let tabVM = TabViewModel()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        // Use a UIHostingController as window root view controller
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            let controller = ContentHostingController(rootView:
                ContentView(
                    accountVM: AccountViewModel(),
                    tabVM: self.tabVM,
                    paymentVM: PaymentGatewayViewModel(),
                    locationVM: LocationListViewModel(),
                    logVM: LogViewModel(),
                    packsVM: PacksViewModel(tabVM: self.tabVM),
                    activityVM: ActivityViewModel(),
                    inboxVM: InboxViewModel(),
                    leaseVM: LeaseListViewModel(),
                    vm: homeVM
                )
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
            SharedActionsService.shared.present = { vc in
                window.rootViewController?.present(vc, animated: true, completion: nil)
            }

            window.makeKeyAndVisible()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.homeVM.showSplash = false
        }
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
        Logger.v("Main", "Scene did become active")
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.homeVM.foreground()

        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }

}
