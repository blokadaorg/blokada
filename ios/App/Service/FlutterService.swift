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

    private lazy var env = Services.env

    private lazy var sheetRepo = Repos.sheetRepo
    private lazy var appRepo = Repos.appRepo
    private lazy var plusRepo = Repos.plusRepo
    private lazy var linkRepo = Repos.linkRepo

    private lazy var stageHot = Repos.stageRepo.stageHot
    private lazy var appStateHot = Repos.appRepo.appStateHot
    private lazy var workingHot = Repos.appRepo.workingHot
    private lazy var accountHot = Repos.accountRepo.accountHot
    private lazy var accountTypeHot = Repos.accountRepo.accountTypeHot
    private lazy var dnsPermsGrantedHot = Repos.permsRepo.dnsProfilePerms
    private lazy var vpnPermsGrantedHot = Repos.permsRepo.vpnProfilePerms
    private lazy var selectedGatewayHot = Repos.gatewayRepo.selectedHot
    private lazy var plusEnabledHot = Repos.plusRepo.plusEnabledHot

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
        // Push the user agent to Flutter
        let sendUserAgent = FlutterMethodChannel(name: "env:userAgent", binaryMessenger: controller.binaryMessenger)
        sendUserAgent.invokeMethod("env:userAgent", arguments: env.userAgent())

        // Push account ID changes to Flutter
        let sendAccount = FlutterMethodChannel(name: "account",
            binaryMessenger: controller.binaryMessenger)
        accountHot.sink(onValue: { it in
            sendAccount.invokeMethod("id", arguments: it.account.id)
            let type = it.account.type?.capitalizingFirstLetter() ?? "Libre"
            Logger.v("FlutterService", "Account type: \(type)")
            sendAccount.invokeMethod("type", arguments: type)
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
        Publishers.CombineLatest4(appStateHot, workingHot, plusEnabledHot, selectedGatewayHot)
        .tryMap { it -> String in
            let (state, working, plus, selectedGateway) = it
            let location = selectedGateway.gateway?.niceName() ?? ""
            return "{\"state\":\"\(state)\",\"working\":\(working),\"plus\":\(plus), \"location\":\"\(location)\"}"
        }
        .removeDuplicates()
        .sink(onValue: { it in
            Logger.v("FlutterService", "Passing new app state: \(it)")
            appState.invokeMethod("app:state", arguments: it)
        })
        .store(in: &cancellables)

        // Change app state
        let changeAppState = FlutterMethodChannel(name: "app:changeState",
            binaryMessenger: controller.binaryMessenger)
        changeAppState.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if self.working {
            } else if !self.accountActive {
                self.sheetRepo.showSheet(.Payment)
            } else if !self.dnsPermsGranted {
                self.sheetRepo.showSheet(.Activated)
            } else if !self.vpnPermsGranted && self.accountType == .Plus {
                self.sheetRepo.showSheet(.Activated)
            } else if self.appState == .Activated {
                self.sheetRepo.showPauseMenu(true)
            } else if self.appState == .Paused {
                self.appRepo.unpauseApp()
            } else {
                // At this point app is just active (and user cannot tap this).
                // Or there is no connectivity and app did not start.
                // In that case, trigger the flow.
                self.appRepo.unpauseApp()
            }
        })

        // Plus actions
        let plus = FlutterMethodChannel(name: "plus", binaryMessenger: controller.binaryMessenger)
        plus.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "openLocations" {
                if !self.accountActive {
                    self.sheetRepo.showSheet(.Payment)
                } else if self.accountType == .Cloud {
                    self.linkRepo.openLink(Link.ManageSubscriptions)
                } else if !self.vpnPermsGranted {
                    self.sheetRepo.showSheet(.Activated)
                } else {
                    self.sheetRepo.showSheet(.Location)
                }
            } else if call.method == "switchPlus" {
                let on = call.arguments as? Bool
                if let o = on, o {
                    self.plusRepo.switchPlusOn()
                } else {
                    self.plusRepo.switchPlusOff()
                }
            }
        })

        // Push app stage (foreground) to Flutter
        let appStage = FlutterMethodChannel(name: "stage:foreground",
            binaryMessenger: controller.binaryMessenger)
        stageHot
        .sink(onValue: { it in
            if it == AppStage.Foreground {
                appStage.invokeMethod("stage:foreground", arguments: true)
            } else {
                appStage.invokeMethod("stage:foreground", arguments: false)
            }
        })
        .store(in: &cancellables)

        workingHot.sink(onValue: { it in self.working = it }).store(in: &cancellables)
        appStateHot.sink(onValue: { it in self.appState = it }).store(in: &cancellables)
        accountHot.sink(onValue: { it in self.accountActive = it.account.isActive() }).store(in: &cancellables)
        accountTypeHot.sink(onValue: { it in self.accountType = it }).store(in: &cancellables)
        dnsPermsGrantedHot.sink(onValue: { it in self.dnsPermsGranted = it }).store(in: &cancellables)
        vpnPermsGrantedHot.sink(onValue: { it in self.vpnPermsGranted = it }).store(in: &cancellables)

        Logger.v("FlutterService", "All channels are set up")
    }

}
