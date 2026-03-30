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
    private let startupVisualGate = StartupVisualGate()
    private var firstFlutterFrameObserver: NSObjectProtocol?

    @Injected(\.stage) private var foreground
    @Injected(\.commands) private var commands

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        StartupContext.shared.normalizeForUiSceneIfNeeded()

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
                guard self.startupVisualGate.hasCompletedInitialSplashRelease else {
                    return
                }

                if transitioning {
                    self.homeVM.showSplash = transitioning
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard self.startupVisualGate.hasCompletedInitialSplashRelease else {
                            return
                        }

                        if !self.startupVisualGate.isContentTemporarilyHiddenForLifecycle {
                            self.homeVM.showSplash = false
                        }
                    }
                }
            }

            window.rootViewController = controller
            self.window = window
            Services.dialog.setController(controller)
            startupVisualGate.bind(homeVM: homeVM)
            registerFirstFlutterFrameObserver()

            window.makeKeyAndVisible()
            startupVisualGate.startInitialSplashRelease(
                hasSeenFirstFlutterFrame: StartupContext.shared.hasSeenFirstFlutterFrame
            )
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
        startupVisualGate.handleSceneDidBecomeActive()
        StartupContext.shared.markForegroundInteractive()
        foreground.onForeground(true)
        
        // For iPad and macOS, register for enhanced focus monitoring
        if UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac {
            registerForEnhancedFocusNotifications()
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).`

        // Close the kb when leaving to bg
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        startupVisualGate.handleSceneWillResignActive()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        StartupContext.shared.normalizeForUiSceneIfNeeded()
        startupVisualGate.handleSceneWillEnterForeground()
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
    
    // MARK: - macOS Compatibility Mode Support
    
    
    private func registerForEnhancedFocusNotifications() {
        let platform = ProcessInfo.processInfo.isiOSAppOnMac ? "macOS" : "iPad"
        BlockaLogger.w("SceneDelegate", "SUCCESS: Using scene notifications for \(platform) window focus detection!")
        
        // Use scene-level notifications for focus/defocus detection on iPad and macOS
        NotificationCenter.default.removeObserver(self, name: UIScene.didActivateNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIScene.willDeactivateNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneDidActivate),
            name: UIScene.didActivateNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillDeactivate),
            name: UIScene.willDeactivateNotification,
            object: nil
        )
        
        BlockaLogger.w("SceneDelegate", "Registered \(platform) window focus detection using scene notifications")
    }
    
    
    @objc private func sceneDidActivate() {
        // Only process if running on iPad or Mac
        guard UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac else { 
            return 
        }
        
        let platform = ProcessInfo.processInfo.isiOSAppOnMac ? "macOS" : "iPad"
        BlockaLogger.w("SceneDelegate", "\(platform): Window gained focus")
        startupVisualGate.handleSceneDidBecomeActive()
        foreground.onForeground(true)
    }
    
    @objc private func sceneWillDeactivate() {
        // Only process if running on iPad or Mac
        guard UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac else { 
            return 
        }
        
        let platform = ProcessInfo.processInfo.isiOSAppOnMac ? "macOS" : "iPad"
        BlockaLogger.w("SceneDelegate", "\(platform): Window lost focus")
        
        // Close the keyboard when losing focus
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        startupVisualGate.handleSceneWillResignActive()
        foreground.onForeground(false)
    }
    
    deinit {
        if let observer = firstFlutterFrameObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Clean up notifications
        if UIDevice.current.userInterfaceIdiom == .pad || ProcessInfo.processInfo.isiOSAppOnMac {
            NotificationCenter.default.removeObserver(self)
        }
    }

    private func registerFirstFlutterFrameObserver() {
        if let observer = firstFlutterFrameObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        firstFlutterFrameObserver = NotificationCenter.default.addObserver(
            forName: StartupContext.firstFlutterFrameRenderedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startupVisualGate.handleFirstFlutterFrame()
        }
    }
}

private final class StartupVisualGate {
    private let log = BlockaLogger("StartupVisualGate")
    private weak var homeVM: HomeViewModel?
    private var fallbackWorkItem: DispatchWorkItem?

    private(set) var hasSeenFirstFlutterFrame = false
    private(set) var isContentTemporarilyHiddenForLifecycle = false
    private(set) var hasCompletedInitialSplashRelease = false

    private let initialSplashFallbackDelay: TimeInterval = 8

    func bind(homeVM: HomeViewModel) {
        self.homeVM = homeVM
        applyCurrentState()
    }

    func startInitialSplashRelease(hasSeenFirstFlutterFrame: Bool) {
        self.hasSeenFirstFlutterFrame = hasSeenFirstFlutterFrame
        applyCurrentState()

        guard !hasCompletedInitialSplashRelease else {
            return
        }

        if hasSeenFirstFlutterFrame {
            completeInitialSplashRelease(reason: "first-frame-already-seen")
            return
        }

        scheduleFallbackIfNeeded()
    }

    func handleFirstFlutterFrame() {
        hasSeenFirstFlutterFrame = true
        completeInitialSplashRelease(reason: "flutter-first-frame")
    }

    func handleSceneDidBecomeActive() {
        isContentTemporarilyHiddenForLifecycle = false
        applyCurrentState()
    }

    func handleSceneWillEnterForeground() {
        isContentTemporarilyHiddenForLifecycle = false
        applyCurrentState()
    }

    func handleSceneWillResignActive() {
        isContentTemporarilyHiddenForLifecycle = true
        applyCurrentState()
    }

    private func completeInitialSplashRelease(reason: String) {
        guard !hasCompletedInitialSplashRelease else {
            return
        }

        fallbackWorkItem?.cancel()
        fallbackWorkItem = nil
        hasCompletedInitialSplashRelease = true
        log.v("Releasing initial splash: \(reason)")
        applyCurrentState()
    }

    private func scheduleFallbackIfNeeded() {
        guard fallbackWorkItem == nil else {
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.hasCompletedInitialSplashRelease else {
                return
            }

            self.log.w("Initial splash fallback fired before Flutter first frame")
            self.completeInitialSplashRelease(reason: "fallback")
        }

        fallbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + initialSplashFallbackDelay, execute: workItem)
    }

    private func applyCurrentState() {
        guard let homeVM = homeVM else {
            return
        }

        homeVM.showSplash = !hasCompletedInitialSplashRelease
        homeVM.hideContent = hasCompletedInitialSplashRelease && isContentTemporarilyHiddenForLifecycle
    }
}
