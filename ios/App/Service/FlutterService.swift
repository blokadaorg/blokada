//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Flutter
import Combine

class FlutterService {

    lazy var flutterEngine = FlutterEngine(name: "common")

    private lazy var sheetRepo = Repos.sheetRepo
    private lazy var appRepo = Repos.appRepo

    private lazy var accountIdHot = Repos.accountRepo.accountIdHot
    private lazy var appStateHot = Repos.appRepo.appStateHot
    private lazy var workingHot = Repos.appRepo.workingHot
    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var accountTypeHot = Repos.accountRepo.accountTypeHot
    private lazy var dnsPermsGrantedHot = Repos.permsRepo.dnsProfilePerms
    private lazy var vpnPermsGrantedHot = Repos.permsRepo.vpnProfilePerms

    // All fields below are used by defining power button action
    private var working: Bool = false
    private var appState: AppState = AppState.Deactivated
    private var accountActive: Bool = false
    private var accountType: AccountType = AccountType.Libre
    private var dnsPermsGranted: Bool = false
    private var vpnPermsGranted: Bool = false

    private var cancellables = Set<AnyCancellable>()

    var shareCounter: Int = 0

    func start() {
        flutterEngine.run()
    }

    func setupChannels(controller: FlutterViewController) {
        // Push account ID changes to Flutter
        let sendAccountId = FlutterMethodChannel(name: "account:id",
            binaryMessenger: controller.binaryMessenger)
        accountIdHot.sink(onValue: { it in
            sendAccountId.invokeMethod("account:id", arguments: it)
        })
        .store(in: &cancellables)

        // Share counter
        let share = FlutterMethodChannel(name: "share",
            binaryMessenger: controller.binaryMessenger)
        share.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            let counter = call.arguments as? Int
            if let c = counter {
                self.shareCounter = c
                self.sheetRepo.showSheet(.ShareAdsCounter)
            }
        })

        // Push app state changes to Flutter
        let appState = FlutterMethodChannel(name: "app:state",
            binaryMessenger: controller.binaryMessenger)
        Publishers.CombineLatest(appStateHot, workingHot)
        .sink(onValue: { it in
            let (state, working) = it
            let parsed = "{\"state\":\"\(state)\",\"working\":\(working),\"plus\":false}"
            appState.invokeMethod("app:state", arguments: parsed)
        })
        .store(in: &cancellables)

        // Change app state
        let changeAppState = FlutterMethodChannel(name: "app:changeState",
            binaryMessenger: controller.binaryMessenger)
        changeAppState.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            let unpause = call.arguments as? Bool
            if let u = unpause {
                if self.working {
                } else if !self.accountActive {
                    self.sheetRepo.showSheet(.Payment)
                } else if !self.dnsPermsGranted {
                    self.sheetRepo.showSheet(.Activated)
                } else if !self.vpnPermsGranted && self.accountType == .Plus {
                    self.sheetRepo.showSheet(.Activated)
                } else if self.appState == .Activated {
                    self.appRepo.pauseApp(until: nil)
                } else if self.appState == .Paused {
                    self.appRepo.unpauseApp()
                } else {
                    // At this point app is just active (and user cannot tap this).
                    // Or there is no connectivity and app did not start.
                    // In that case, trigger the flow.
                    self.appRepo.unpauseApp()
                }
            }
        })

        workingHot.sink(onValue: { it in self.working = it }).store(in: &cancellables)
        appStateHot.sink(onValue: { it in self.appState = it }).store(in: &cancellables)
        accountHot.sink(onValue: { it in self.accountActive = it.account.isActive() }).store(in: &cancellables)
        accountTypeHot.sink(onValue: { it in self.accountType = it }).store(in: &cancellables)
        dnsPermsGrantedHot.sink(onValue: { it in self.dnsPermsGranted = it }).store(in: &cancellables)
        vpnPermsGrantedHot.sink(onValue: { it in self.vpnPermsGranted = it }).store(in: &cancellables)

        Logger.v("FlutterService", "All channels are set up")
    }

}
