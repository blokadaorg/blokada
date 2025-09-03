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

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UIGestureRecognizerDelegate {

    var window: UIWindow?

    private let homeVM = ViewModels.home

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
        
        // For macOS compatibility mode, also register for focus monitoring
        if ProcessInfo.processInfo.isiOSAppOnMac {
            lastKnownFocusState = true  // Initialize as focused
            registerForMacOSFocusNotifications()
        }
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
    
    // MARK: - macOS Compatibility Mode Support
    
    private var sceneStateTimer: Timer?
    private var lastKnownFocusState: Bool = true
    
    private func registerForMacOSFocusNotifications() {
        BlockaLogger.w("SceneDelegate", "LIMITATION: 'Designed for iPad' apps on macOS cannot detect window focus changes")
        BlockaLogger.w("SceneDelegate", "LIMITATION: All iOS APIs (scene state, window properties) remain 'active' even when unfocused")
        BlockaLogger.w("SceneDelegate", "SOLUTION: Implementing user interaction-based focus detection as workaround")
        
        // Clean up any existing timer
        sceneStateTimer?.invalidate()
        
        // Register for user interaction events to detect when user is actively using the app
        registerForUserInteractionDetection()
        
        // Keep app-level notifications for minimize/restore (these do work)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        BlockaLogger.w("SceneDelegate", "Started macOS workaround: user interaction-based focus detection")
    }
    
    private func registerForUserInteractionDetection() {
        // Start a timer that detects recent user interaction
        sceneStateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkUserInteractionBasedFocus()
        }
        
        // Add gesture recognizers to detect user interaction
        if let window = window {
            // Tap gesture for clicks
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(userDidInteract))
            tapGesture.cancelsTouchesInView = false
            tapGesture.delegate = self
            window.addGestureRecognizer(tapGesture)
            
            // Pan gesture for drags/swipes
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(userDidInteract))
            panGesture.cancelsTouchesInView = false
            panGesture.delegate = self
            window.addGestureRecognizer(panGesture)
            
            // Add a custom view that can detect hover/mouse movement for macOS
            let hoverDetectionView = HoverDetectionView { [weak self] in
                self?.userDidInteract()
            }
            hoverDetectionView.isUserInteractionEnabled = false // Don't block other interactions
            hoverDetectionView.frame = window.bounds
            hoverDetectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            window.addSubview(hoverDetectionView)
            window.sendSubviewToBack(hoverDetectionView) // Keep it behind everything else
        }
    }
    
    private var lastUserInteraction: Date = Date()
    private let focusTimeoutInterval: TimeInterval = 10.0 // Consider unfocused after 10 seconds of no interaction
    
    @objc private func userDidInteract() {
        lastUserInteraction = Date()
        
        // If we were considered unfocused, we just regained focus
        if !lastKnownFocusState {
            lastKnownFocusState = true
            BlockaLogger.w("SceneDelegate", "macOS: User interaction detected - assuming focus regained")
            homeVM.hideContent = false
            foreground.onForeground(true)
        }
    }
    
    private func checkUserInteractionBasedFocus() {
        guard ProcessInfo.processInfo.isiOSAppOnMac else { return }
        
        let timeSinceLastInteraction = Date().timeIntervalSince(lastUserInteraction)
        let shouldBeFocused = timeSinceLastInteraction < focusTimeoutInterval
        
        if shouldBeFocused != lastKnownFocusState {
            lastKnownFocusState = shouldBeFocused
            
            if shouldBeFocused {
                BlockaLogger.w("SceneDelegate", "macOS: Assumed focus based on recent interaction")
                homeVM.hideContent = false
                foreground.onForeground(true)
            } else {
                BlockaLogger.w("SceneDelegate", "macOS: Assumed unfocused - no interaction for \(timeSinceLastInteraction)s")
                
                // Close the keyboard when losing focus
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                homeVM.hideContent = true
                foreground.onForeground(false)
            }
        }
    }
    
    @objc private func appDidBecomeActive() {
        // Only process if running on Mac
        guard ProcessInfo.processInfo.isiOSAppOnMac else { 
            BlockaLogger.v("SceneDelegate", "DEBUG: appDidBecomeActive called but not on Mac")
            return 
        }
        
        BlockaLogger.w("SceneDelegate", "DEBUG: NOTIFICATION - appDidBecomeActive fired!")
        lastKnownFocusState = true
        homeVM.hideContent = false
        foreground.onForeground(true)
    }
    
    @objc private func appWillResignActive() {
        // Only process if running on Mac
        guard ProcessInfo.processInfo.isiOSAppOnMac else { 
            BlockaLogger.v("SceneDelegate", "DEBUG: appWillResignActive called but not on Mac")
            return 
        }
        
        BlockaLogger.w("SceneDelegate", "DEBUG: NOTIFICATION - appWillResignActive fired!")
        lastKnownFocusState = false
        
        // Close the keyboard when losing focus
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        homeVM.hideContent = true
        foreground.onForeground(false)
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true // Allow our gesture recognizers to work alongside other gestures
    }
    
    deinit {
        // Clean up notifications and timer
        if ProcessInfo.processInfo.isiOSAppOnMac {
            NotificationCenter.default.removeObserver(self)
            sceneStateTimer?.invalidate()
            sceneStateTimer = nil
        }
    }
}

// MARK: - Hover Detection View for macOS

class HoverDetectionView: UIView {
    private let onHover: () -> Void
    
    init(onHover: @escaping () -> Void) {
        self.onHover = onHover
        super.init(frame: .zero)
        backgroundColor = .clear
        
        // Enable hover detection for macOS
        if ProcessInfo.processInfo.isiOSAppOnMac {
            let hoverGesture = UIHoverGestureRecognizer(target: self, action: #selector(hoverDetected(_:)))
            addGestureRecognizer(hoverGesture)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func hoverDetected(_ gesture: UIHoverGestureRecognizer) {
        switch gesture.state {
        case .began, .changed:
            onHover()
        default:
            break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Don't intercept touches - let them pass through to underlying views
        return nil
    }
}
