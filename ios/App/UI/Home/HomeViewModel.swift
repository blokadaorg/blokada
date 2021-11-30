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

import Foundation
import UIKit

class HomeViewModel: ObservableObject {

    private let log = Logger("Home")
    private let network = NetworkService.shared
    private let vpn = VpnService.shared
    private let api = BlockaApiService.shared
    private let notification = NotificationService.shared
    private let sharedActions = SharedActionsService.shared
    private let expiration = ExpirationService.shared
    private let networkDns = NetworkDnsService.shared

    init() {
        sharedActions.changeGateway = switchGateway
        sharedActions.refreshStats = { ok in
            self.refreshAdsCounter(delay: false, ok: ok)
        }
        sharedActions.refreshPauseInformation = { paused in
            self.log.v("Refreshing pause info")
            if !paused {
                self.stopTimer()
            } else {
                self.startTimer(seconds: 300)
            }
        }
        Config.shared.setOnConfigUpdated {
            onMain {
                self.syncUiWithConfig()
                self.syncUiWithTunnel(done: { _, _ in } )
            }
        }
        Config.shared.setOnAccountIdChanged {
            onMain {
                self.blockedCounter = 0
                self.refreshAdsCounter(delay: false)
            }
        }
        network.onStatusChanged = { status in
            onMain {
                self.working = status.inProgress
                //self.mainSwitch = self.working ? self.mainSwitch : status.active
                Config.shared.setVpnEnabled(status.hasGateway())
                self.syncUiWithConfig()
            }
        }
        expiration.setOnExpired {
            self.showExpiredAlert()
            self.stopTimer()
        }
    }

    /**
        Properties used by the HomeView
     */

    @Published var showSplash = true

    @Published var working: Bool = false

    @Published var showError: Bool = false
    var errorHeader: String? = nil
    var error: String? = nil {
        didSet {
            if error != nil {
                showError = true
            } else {
                showError = false
                errorHeader = nil
                if showExpired {
                    showExpired = false
                    expiredAlertShown = false
                }
            }
        }
    }

    private var showExpired: Bool = false {
        didSet {
            if showExpired {
                errorHeader = L10n.alertVpnExpiredHeader
                error = L10n.errorVpnExpired
                showError = true
            } else {
                self.turnVpnOffAfterExpired()
                self.notification.clearNotification()
            }
        }
    }
    var expiredAlertShown: Bool = false

    var onAccountExpired = {}

    @Published var mainSwitch: Bool = false
    @Published var vpnEnabled: Bool = false

    @Published var timerSeconds: Int = 0
    private var timerBackgroundTask: UIBackgroundTaskIdentifier = .invalid

    @Published var accountActive = false
    @Published var accountType = ""

    @Published var selectedGateway: Gateway? = nil

    var hasSelectedLocation : Bool {
        return selectedGateway != nil
    }

    var location: String {
        return selectedGateway?.niceName() ?? "None"
    }

    var hasLease: Bool {
        return accountActive && Config.shared.leaseActive()
    }

    @Published var blockedCounter: Int = 0

    var encryptionLevel: Int {
        if working {
            return 1
        } else if !mainSwitch {
            return 1
        } else if !vpnEnabled {
            return 2
        } else {
            return 3
        }
    }

    /**
        Public entrypoints caused by user action
    */

    private var startSuccessful = Atomic<Bool>(false)
    private var startOngoing = Atomic<Bool>(false)

    func ensureAppStartedSuccessfully(_ done: @escaping Callback<Unit>) {
        onBackground {
            if self.startSuccessful.value {
                onMain { done(nil, nil) }
            } else if !self.startOngoing.value {
                self.startOngoing.value = true
                onMain {
                    self.start { error, _ in
                        guard error == nil else {
                            self.startOngoing.value = false
                            onMain { done(error, nil) }
                            return
                        }

                        self.startSuccessful.value = true
                        self.startOngoing.value = false
                        onMain { done(nil, nil) }
                    }
                }
            }
        }
    }

    private func start(_ done: @escaping Callback<Void>) {
        self.log.v("Start")
        self.error = nil
        self.working = true
        self.syncUiWithConfig()

        onBackground {
            self.syncUiWithTunnel { error, status in onMain {
                guard error == nil else {
                    if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                       return onMain {
                           self.log.v("No VPN profile")

                           // Do not treat this as an error
                           return self.afterStart(done)
                       }
                   }

                    self.handleError(CommonError.failedTunnel, cause: error)
                    return done(error, nil)
                }

                if !Config.shared.hasAccount() {
                    // New user scenario: just create account
                    self.sharedActions.newUser { error, _ in
                        guard error == nil else {
                            self.handleError(CommonError.failedFetchingData, cause: error)
                            return done(error, nil)
                        }

                        return self.afterStart(done)
                    }
                } else {
                    // Tunnel is already up and running, check lease and account
                    if status?.hasGateway() ?? false {
                        if !Config.shared.accountActive() || !Config.shared.leaseActive() {
                            //self.log.w("start: Lease expired, showing alert dialog")
                            //self.showExpiredAlert()
                            return self.afterStart(done)
                        } else {
                            self.expiration.update(Config.shared.account()!)
                            return self.afterStart(done)
                        }
                    } else {
                         return self.afterStart(done)
                    }
                }
            }}
        }
    }

    private func afterStart(_ done: @escaping Callback<Void>) {
        self.log.v("Start procedure done")
        self.working = false
        done(nil, nil)

        onBackground {
            if !Config.shared.accountActive() {
                PaymentService.shared.refreshProductsAfterStart()
            }

            // Check lease on every fresh app start if using vpn
            if Config.shared.vpnEnabled() {
                self.recheckActiveLeaseAfterActivating()
            }
        }
    }

    func foreground() {
        self.log.v("App entered foreground")
        syncUiWithConfig()
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                self.maybeSyncUserAfterForeground()

                self.syncUiWithTunnel { error, status in onMain {
                    guard error == nil else {
                        if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                           return self.log.v("No VPN profile")
                        }
                        return self.log.e("Foreground: failed syncing tunnel".cause(error))
                    }

                    if let pause = status?.pauseSeconds {
                        if self.timerSeconds != pause {
                            self.log.v("Foreground: syncing pause timer, NETX reported \(pause)s")
                            if self.timerSeconds == 0 {
                                self.startTimer(seconds: pause)
                            } else if pause == 0 {
                                self.stopTimer()
                            } else {
                                self.timerSeconds = pause
                            }
                        }
                    }

                    self.expiration.update(Config.shared.account())

                    // Check if tunnel should stay active
                    if status?.hasGateway() ?? false {
                        if !Config.shared.accountActive() || !Config.shared.leaseActive() {
                            // No active lease
                            //self.showExpiredAlert()
                            //self.log.w("Foreground: lease expired, showing alert dialog")
                        } else {
                            if (Config.shared.hasLease()) {
                                self.recheckActiveLeaseAfterActivating()
                                self.log.v("Foreground: synced (lease active)")
                            } else {
                                self.log.w("Foreground: synced: missing lease")
                            }
                        }
                    } else { // TODO: if cloud, and no active account, popup cta here?
                        self.log.v("Foreground: synced")
                    }
                }}
            }
        }

        // We don't need the background task if we are in foreground
        if timerSeconds != 0 {
            self.endBackgroundTask()
        }
    }

    func background() {
        self.log.v("App entered background")
        if timerSeconds != 0 {
            self.registerBackgroundTask()
        }
    }

    private let ACCOUNT_REFRESH_SEC: Double = 10 * 60 // Same as on Android
    private var lastOnForeground: Double = 0
    private func maybeSyncUserAfterForeground() {
        if Date().timeIntervalSince1970 < lastOnForeground + ACCOUNT_REFRESH_SEC {
            return
        }

        // Check account on foreground at least once a day
        self.log.v("Foreground: check account after foreground")
        self.api.getAccount(id: Config.shared.accountId()) { error, account in
            if let account = account {
                self.lastOnForeground = Date().timeIntervalSince1970

                self.log.v("Foreground: updating account after foreground")
                SharedActionsService.shared.updateAccount(account)

                // Account got inactive from backend, turn off vpn and inform the user
                if !Config.shared.accountActive() && Config.shared.vpnEnabled() {
                    self.log.w("Foreground: account got deactivated")
                    self.expiration.update(nil)
                }
            }
        }

    }

    private func showExpiredAlert() {
        onMain {
            guard !self.expiredAlertShown else { return }
            self.expiredAlertShown = true

            // Hide the current displaying sheet, if any
            self.onAccountExpired()

            // Wait (seems to be necessary)
            onBackground {
                sleep(1)
                onMain {
                    // Show the alert
                    self.showExpired = true
                }
            }
        }
    }

    func switchMain(activate: Bool, noPermissions: @escaping Ok<Void>, showRateScreen: @escaping Ok<Void>, dnsProfileConfigured: @escaping Ok<Void>, noActiveAccount: @escaping Ok<Void>) {
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                self.log.v("User action: switchMain: \(activate)")
                self.working = true

                let cfg = Config.shared
                if activate {
                    // Turning on
                    if (!cfg.accountActive()) {
                        // Payment popup
                        self.log.v("User action: switchMain: no active account")
                        self.working = false
                        self.mainSwitch = false
                        return onMain { noActiveAccount(()) }
                    }

                    // Ask for permission to send notifications after power on
                    defer { self.notification.askForPermissions() }

                    if (!cfg.vpnEnabled()) {
                        // Cloud mode
                        self.api.getCurrentDevice { error, device in
                            guard error == nil else {
                                return self.handleError(CommonError.unknownError, cause: error)
                            }

                            guard let tag = device?.device_tag else {
                                return self.handleError(CommonError.unknownError, cause: "No device tag")
                            }

                            cfg.setDeviceTag(tag: tag)

                            self.networkDns.saveBlokadaNetworkDns(tag: tag, name: cfg.deviceName()) { error, _ in
                                guard error == nil else {
                                    return self.handleError(CommonError.unknownError, cause: error)
                                }

                                // It is possible the profile is already activated by the user
                                self.networkDns.isBlokadaNetworkDnsEnabled { error, dnsEnabled in
                                    guard dnsEnabled == true else {
                                        // If not, show the prompt
                                        self.mainSwitch = false
                                        self.working = false
                                        self.log.v("User action: switchMain: done, dns profile unactivated")
                                        return onMain { dnsProfileConfigured(()) }
                                    }

                                    self.mainSwitch = true
                                    self.working = false
                                    self.log.v("User action: switchMain: done")

                                    self.refreshAdsCounter(delay: true) {
                                        if self.shouldShowRateScreen() {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                                                showRateScreen(())
                                            })
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Plus mode
                        self.network.queryStatus { error, status in onMain {
                            guard error == nil else {
                                if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                                    return onMain {
                                        self.log.v("Showing ask for VPN sheet")
                                        self.working = false
                                        self.mainSwitch = false
                                        self.syncUiWithConfig()
                                        return onMain { noPermissions(()) }
                                    }
                                } else {
                                    return self.handleError(CommonError.failedTunnel, cause: error)
                                }
                            }

                            guard let status = status else {
                                return self.handleError(CommonError.failedTunnel, cause: error)
                            }

                            if cfg.hasLease() && cfg.leaseActive() {
                                // Vpn should be on, and lease is OK
                                self.vpn.applyGatewayFromConfig() { error, _ in onMain {
                                    guard error == nil else {
                                        cfg.clearLease()
                                        return self.handleError(CommonError.failedTunnel, cause: error)
                                    }

                                    self.expiration.update(cfg.account())
                                    self.recheckActiveLeaseAfterActivating()
                                    self.refreshAdsCounter(delay: true)
                                    self.log.v("User action: switchMain: done")
                                }}
                            } else if cfg.hasLease() && cfg.accountActive() {
                                // Vpn should be on, but lease expired, refresh
                                self.refreshLease { error, _ in onMain {
                                    guard error == nil else {
                                        cfg.clearLease()
                                      return self.handleError(CommonError.failedFetchingData, cause: error)
                                    }

                                    self.vpn.applyGatewayFromConfig() { error, _ in onMain {
                                        guard error == nil else {
                                            cfg.clearLease()
                                            return self.handleError(CommonError.failedTunnel, cause: error)
                                        }

                                        self.expiration.update(cfg.account())
                                        self.refreshAdsCounter(delay: true)
                                        self.log.v("User action: switchMain: done")
                                    }}
                                }}
                            } else {
                                // Vpn should be on, but account has expired
                                cfg.clearLease()
                                return self.handleError(CommonError.accountInactive, cause: error)
                            }
                        }}
                    }
                } else {
                    // Turning off
                    self.network.queryStatus { error, status in onMain {
                        guard error == nil, let status = status else {
                            if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                                self.working = false
                                self.mainSwitch = false
                                self.stopTimer()
                                return self.log.v("User action: switchMain: done (no vpn perms)")
                            }
                            return self.handleError(CommonError.failedTunnel, cause: error)
                        }

                        if status.active {
                            // Turn off VPN
                            self.stopTimer()
                            self.vpn.turnOffEverything { error, _ in onMain {
                                guard error == nil else {
                                    return self.handleError(CommonError.failedTunnel, cause: error)
                                }

                                self.error = nil
                                self.log.v("User action: switchMain: done")
                            }}
                        } else {
                            // Turning off Cloud is not possible, show a message TODO?
                            self.working = false
                            self.mainSwitch = false
                            self.stopTimer()
                            self.log.v("User action: switchMain: done")
                        }
                    }}
                }
            }
        }
    }

    private func recheckActiveLeaseAfterActivating() {
        onBackground {
            self.log.v("Check lease after start")
            self.api.getCurrentLease { error, lease in
                guard error == nil else { return }

                if !(lease?.isActive() ?? false) {
                    self.log.w("Lease got deactivated, recreating")
                    self.expiration.update(nil)
                }
            }
        }
    }

    func switchVpn(activate: Bool, noPermissions: @escaping Ok<Void>) {
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                Config.shared.setVpnEnabled(activate)
                self.log.v("User action: switchVpn: \(activate)")

                self.network.queryStatus { error, status in onMain {
                    guard error == nil else {
                        Config.shared.setVpnEnabled(false)
                        if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                            return onMain {
                                self.log.v("Showing ask for VPN sheet")
                                self.syncUiWithConfig()
                                return noPermissions(())
                            }
                        } else {
                            return self.handleError(CommonError.failedTunnel, cause: error)
                        }
                    }

                    guard let status = status else {
                        Config.shared.setVpnEnabled(false)
                        return self.handleError(CommonError.failedTunnel, cause: error)
                    }

                    if activate {
                        if !Config.shared.accountActive() {
                            Config.shared.setVpnEnabled(false)
                            return self.handleError(CommonError.accountInactive)
                        } else if !Config.shared.hasLease() || !Config.shared.leaseActive() {
                            self.log.v("No location selected")
                            onMain { self.syncUiWithConfig() }
                            Config.shared.setVpnEnabled(false)
                            return
                        } else {
                            self.vpn.applyGatewayFromConfig() { error, _ in onMain {
                                guard error == nil else {
                                    Config.shared.setVpnEnabled(false)
                                    return self.handleError(CommonError.failedVpn, cause: error)
                                }

                                self.expiration.update(Config.shared.account())
                                self.recheckActiveLeaseAfterActivating()
                                self.log.v("User action: switchVpn: done")
                            }}
                        }
                    } else if !activate && Config.shared.hasGateway() {
                        self.vpn.turnOffEverything { error, _ in onMain {
                            guard error == nil else {
                                return self.handleError(CommonError.failedVpn, cause: error)
                            }

                            self.log.v("User action: switchVpn: done")
                        }}
                    } else {
                        self.log.v("User action: switchVpn: done")
                    }
                }}
            }
        }
    }

    func switchGateway(new: Gateway, noPermissions: @escaping Ok<Void>) {
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                self.log.v("User action: switchGateway: \(new.public_key)")
                self.working = true

                let leaseRequest = LeaseRequest(
                    account_id: Config.shared.accountId(),
                    public_key: Config.shared.publicKey(),
                    gateway_id: new.public_key,
                    alias: Env.aliasForLease
                )

                self.api.postLease(request: leaseRequest) { error, lease in onMain {
                    guard error == nil else {
                        if let e = error as? CommonError, e == CommonError.tooManyLeases {
                            return self.api.deleteLeasesWithAliasOfCurrentDevice(id: Config.shared.accountId()) { deleteError, _ in
                                if let deleteError = deleteError {
                                    // Return the initial error instead
                                    self.log.e("Deleting existing lease for same alias failed".cause(deleteError))
                                    return self.handleError(CommonError.failedFetchingData, cause: error)
                                }

                                // We managed to free up the lease limit, try creating the lease again
                                return self.switchGateway(new: new, noPermissions: noPermissions)
                            }
                        } else {
                            return self.handleError(CommonError.failedFetchingData, cause: error)
                        }
                    }

                    Config.shared.setLease(lease!, new)

                    self.vpn.applyGatewayFromConfig() { error, _ in
                        onMain {
                            guard error == nil else {
                                if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                                    return onMain {
                                        self.log.v("Showing ask for VPN sheet")
                                        self.working = false
                                        self.syncUiWithConfig()
                                        return noPermissions(())
                                    }
                                } else {
                                    return self.handleError(CommonError.failedTunnel, cause: error)
                                }
                            }

                            self.expiration.update(Config.shared.account())
                            self.log.v("User action: switchGateway: done")
                        }
                    }
                }}
            }
        }
    }

    func turnVpnOffAfterExpired() {
       onBackground {
           self.ensureAppStartedSuccessfully { error, _ in
               guard error == nil else {
                   return
               }

               self.log.v("User action: turnVpnOffAfterExpired")

               Config.shared.setVpnEnabled(false)
               Config.shared.clearLease()
               self.vpn.turnOffEverything { _, _ in }

               self.network.queryStatus { error, status in onMain {
                   guard error == nil else {
                        self.mainSwitch = false
                        self.working = false
                        return self.handleError(CommonError.failedTunnel, cause: error)
                   }

                   self.log.v("User action: turnVpnOffAfterExpired done")
               }}
           }
       }
   }

    /**
        Private methods used by those public entrypoints
    */

    private func syncUiWithConfig() {
        if Config.shared.hasLease() && self.selectedGateway?.public_key != Config.shared.gateway()?.public_key {
            self.selectedGateway = Config.shared.gateway()
        } else if !Config.shared.hasLease() && self.selectedGateway != nil {
            self.selectedGateway = nil
        }

        if Config.shared.hasAccount() && Config.shared.hasKeys() {
            self.accountActive = Config.shared.accountActive()
            self.accountType = Config.shared.accountType()
        }

        self.vpnEnabled = Config.shared.vpnEnabled()
    }

    private func syncUiWithTunnel(done: @escaping Callback<NetworkStatus>) {
        self.log.v("Sync UI with NETX")
        
        // Blokada Cloud may be configured, but when there is no active account, it will be passthrough.
        if !self.accountActive {
            return onMain {
                self.mainSwitch = false
                self.working = false
                return done(nil, NetworkStatus.disconnected())
            }
        }

        networkDns.isBlokadaNetworkDnsEnabled { error, dnsEnabled in onMain {
            guard error == nil else {
                self.log.w("Could not get NetworkDns state".cause(error))
                self.mainSwitch = false
                self.working = false
                return done(error, nil)
            }

            let mainSwitch = dnsEnabled ?? false

            self.network.queryStatus { error, status in onMain {
                guard let status = status else {
                    self.log.v("  NETX not active".cause(error))
                    self.mainSwitch = mainSwitch
                    Config.shared.setVpnEnabled(false)
                    self.working = false
                    return done(error, nil)
                }

                if status.inProgress {
                    self.log.v(" NETX in progress")
                    //self.mainSwitch = false
                    //self.vpnEnabled = false
                    self.working = true
                    return done(nil, status)
                } else if status.active {
                    self.log.v(" NETX active")
                    self.refreshAdsCounter(delay: false)
                    if status.hasGateway() {
                        self.log.v("  Connected to gateway: \(status.gatewayId!)")
                        self.mainSwitch = true
                        Config.shared.setVpnEnabled(true)
                        self.working = false

                        if !Config.shared.hasLease() || Config.shared.gateway()?.public_key != status.gatewayId! {
                            self.log.w("Gateway and lease mismatch, disconnecting VPN")
                            self.turnVpnOffAfterExpired()
                            return done(nil, nil)
                        } else {
                            return done(nil, status)
                        }
                    } else {
                        self.log.w(" NETX in Libre mode, this should not happen")
                        self.mainSwitch = true
                        Config.shared.setVpnEnabled(false)
                        self.working = false
                        return done(nil, status)
                    }
                } else if (mainSwitch) {
                    self.log.v(" NETX inactive, Cloud mode")
                    self.mainSwitch = true
                    Config.shared.setVpnEnabled(false)
                    self.working = false
                    return done(nil, status)
                } else {
                    self.log.v(" NETX inactive, app deactivated")
                    self.mainSwitch = false
                    Config.shared.setVpnEnabled(false)
                    self.working = false
                    return done(nil, status)
                }
            }}
        }}
    }

    private func handleError(_ error: CommonError, cause: Error? = nil) {
        onMain {
            self.log.e("\(error)".cause(cause))

            self.error = mapErrorForUser(error, cause: cause)
            self.working = false
            self.syncUiWithConfig()
        }
    }

    private func refreshLease(done: @escaping Callback<Lease>) {
        let leaseRequest = LeaseRequest(
            account_id: Config.shared.accountId(),
            public_key: Config.shared.publicKey(),
            gateway_id: Config.shared.lease()!.gateway_id,
            alias: Env.aliasForLease
        )

        self.api.postLease(request: leaseRequest) { error, lease in onMain {
            guard error == nil else {
                return done(error, nil)
            }

            self.api.getGateways { error, gateways in
                guard error == nil else {
                    return done(error, nil)
                }

                if let gateways = gateways {
                    let currentGateway = gateways.first(where: { it in
                        it.public_key == lease!.gateway_id
                    })

                    Config.shared.setLease(lease!, currentGateway!)
                    done(nil, lease!)
                } else {
                    return done("Empty gateways", nil)
                }
            }
        }}
    }

    func showErrorMessage() -> String {
        if self.error?.count ?? 999 > 128 {
            return L10n.errorUnknown
        } else {
            return self.error!
        }
    }

    func startTimer(seconds: Int) {
        self.log.v("startTimer: starting pause")
        self.timerSeconds = seconds
        self.api.pause(seconds: seconds, done: { _, _ in })
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.timerSeconds = self.timerSeconds - 1
            if self.timerSeconds <= 0 {
                self.stopTimer()
                timer.invalidate()
            }

            if var timeLeft = Int(exactly: UIApplication.shared.backgroundTimeRemaining.rounded()) {
                // It starts from 29 usually, thats why +1
                timeLeft += 1
                if timeLeft % 10 == 0 {
                    self.log.v("Background time left: \(timeLeft)s")
                }
            }
        }
    }

    var isPaused: Bool {
        return self.timerSeconds != 0
    }

    func stopTimer() {
        if self.timerSeconds >= 0 {
            self.timerSeconds = 0
            self.log.v("stopTimer: stopping pause")
            self.api.pause(seconds: 0, done: { _, _ in })
        } else {
            self.timerSeconds = 0
        }
        endBackgroundTask()
    }

    func registerBackgroundTask() {
        self.log.v("Registering background task")
        timerBackgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.stopTimer()
        }
        assert(timerBackgroundTask != .invalid)
    }
      
    func endBackgroundTask() {
        if timerBackgroundTask != .invalid {
        self.log.v("Background task ended")
            UIApplication.shared.endBackgroundTask(timerBackgroundTask)
            timerBackgroundTask = .invalid
        }
    }

    func refreshAdsCounter(delay: Bool, ok: @escaping Ok<Void> = { _ in }) {
        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
            self.api.getCurrentCounterStats { error, stats in
                guard error == nil, let stats = stats else {
                    return self.log.w("refreshAdsCounter: failed api call".cause(error))
                }

                onMain {
                    guard let counter = Int(stats.total_blocked) else {
                        return self.log.w("refreshAdsCounter: could not parse, implement uint64 counter support")
                    }
                    self.blockedCounter = counter
                    ok(())
                }
            }
        })
    }

    private func shouldShowRateScreen() -> Bool {
        return self.blockedCounter >= 40 && !Config.shared.firstRun() && !Config.shared.rateAppShown()
    }
}
