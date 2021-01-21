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

    init() {
        sharedActions.changeGateway = switchGateway
        sharedActions.refreshStats = { ok in
            self.refreshAdsCounter(delay: false, ok: ok)
        }
        Config.shared.setOnConfigUpdated {
            onMain { self.syncUiWithConfig() }
        }
        network.onStatusChanged = { status in
            onMain {
                self.working = status.inProgress
                self.mainSwitch = self.working ? self.mainSwitch : status.active
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

    @Published var accountActive = false

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

    func start(_ done: @escaping Callback<Void>) {
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
                            self.log.w("start: Lease expired, showing alert dialog")
                            self.showExpiredAlert()
                            return self.afterStart(done)
                        } else {
                            self.expiration.update(Config.shared.lease()!)
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

            // Check account on every fresh app start
            self.log.v("Check account after start")
            self.api.getAccount(id: Config.shared.accountId()) { error, account in
                if let account = account {
                    self.log.v("Updating account after start")
                    SharedActionsService.shared.updateAccount(account)

                    // Account got inactive from backend, turn off vpn and inform the user
                    if !Config.shared.accountActive() && Config.shared.vpnEnabled() {
                        self.log.w("Account got deactivated")
                        self.expiration.update(nil)
                    }
                }
            }

            // Check lease on every fresh app start if using vpn
            if Config.shared.vpnEnabled() {
                self.recheckActiveLeaseAfterActivating()
            }
        }
    }

    func foreground() {
        syncUiWithConfig()
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                self.syncUiWithTunnel { error, status in onMain {
                    guard error == nil else {
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

                    // Check if tunnel should stay active
                    if status?.hasGateway() ?? false {
                        if !Config.shared.accountActive() || !Config.shared.leaseActive() {
                            // No active lease
                            self.showExpiredAlert()
                            self.log.w("Foreground: lease expired, showing alert dialog")
                        } else {
                            if (Config.shared.hasLease()) {
                                self.expiration.update(Config.shared.lease())
                                self.recheckActiveLeaseAfterActivating()
                                self.log.v("Foreground: synced (lease active)")
                            } else {
                                self.log.w("Foreground: synced: missing lease")
                            }
                        }
                    } else {
                        self.log.v("Foreground: synced")
                    }
                }}
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

    func switchMain(activate: Bool, noPermissions: @escaping Ok<Void>, showRateScreen: @escaping Ok<Void>) {
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                self.log.v("User action: switchMain: \(activate)")
                self.working = true

                self.network.queryStatus { error, status in onMain {
                    guard error == nil else {
                        if error is CommonError && (error as! CommonError) == CommonError.vpnNoPermissions {
                            return onMain {
                                self.log.v("Showing ask for VPN sheet")
                                self.working = false
                                self.mainSwitch = false
                                self.syncUiWithConfig()
                                return noPermissions(())
                            }
                        } else {
                            return self.handleError(CommonError.failedTunnel, cause: error)
                        }
                    }

                    guard let status = status else {
                        return self.handleError(CommonError.failedTunnel, cause: error)
                    }

                    if activate && !status.active {
                        self.log.v("User action: switchMain: enabling: \(activate)")
                        // Ask for permission to send notifications after power on
                        defer { self.notification.askForPermissions() }
                        self.network.startTunnel { error, _ in onMain {
                            guard error == nil else {
                                return self.handleError(CommonError.failedTunnel, cause: error)
                            }

                            if Config.shared.vpnEnabled() && Config.shared.hasLease() && Config.shared.leaseActive() {
                                // Vpn should be on, and lease is OK
                                self.vpn.changeGateway(lease: Config.shared.lease()!, gateway: Config.shared.gateway()!) { error, _ in onMain {
                                    guard error == nil else {
                                        Config.shared.clearLease()
                                        return self.handleError(CommonError.failedTunnel, cause: error)
                                    }

                                    self.expiration.update(Config.shared.lease())
                                    self.recheckActiveLeaseAfterActivating()
                                    self.refreshAdsCounter(delay: true)
                                    self.log.v("User action: switchMain: done")
                                }}
                            } else if Config.shared.vpnEnabled() && Config.shared.hasLease() && Config.shared.accountActive() {
                                // Vpn should be on, but lease expired, refresh
                                self.refreshLease { error, _ in onMain {
                                    guard error == nil else {
                                        Config.shared.clearLease()
                                      return self.handleError(CommonError.failedFetchingData, cause: error)
                                    }

                                    self.vpn.changeGateway(lease: Config.shared.lease()!, gateway: Config.shared.gateway()!) { error, _ in onMain {
                                        guard error == nil else {
                                            Config.shared.clearLease()
                                            return self.handleError(CommonError.failedTunnel, cause: error)
                                        }

                                        self.expiration.update(Config.shared.lease())
                                        self.refreshAdsCounter(delay: true)
                                        self.log.v("User action: switchMain: done")
                                    }}
                                }}
                            } else if Config.shared.vpnEnabled() && Config.shared.hasLease() {
                                // Vpn should be on, but account has expired
                                Config.shared.clearLease()
                                return self.handleError(CommonError.accountInactive, cause: error)
                            } else {
                                // Filtering only mode
                                self.refreshAdsCounter(delay: true) {
                                    if self.shouldShowRateScreen() {
                                        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                                            showRateScreen(())
                                        })
                                    }
                                }
                                self.log.v("User action: switchMain: done")
                            }
                        }}
                    } else if !activate && status.active {
                        self.stopTimer()
                        self.network.stopTunnel { error, _ in onMain {
                            guard error == nil else {
                                return self.handleError(CommonError.failedTunnel, cause: error)
                            }

                            self.error = nil
                            self.log.v("User action: switchMain: done")
                        }}
                    } else {
                        self.stopTimer()
                        self.working = false
                        self.log.v("User action: switchMain: done")
                    }
                }}
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

    func switchVpn(activate: Bool) {
        onBackground {
            self.ensureAppStartedSuccessfully { error, _ in
                guard error == nil else {
                    return
                }

                Config.shared.setVpnEnabled(activate)
                self.log.v("User action: switchVpn: \(activate)")

                self.network.queryStatus { error, status in onMain {
                    guard let status = status else {
                        Config.shared.setVpnEnabled(false)
                        return self.handleError(CommonError.failedTunnel, cause: error)
                    }

                    if activate && !status.hasGateway() {
                        if !Config.shared.accountActive() {
                            Config.shared.setVpnEnabled(false)
                            return self.handleError(CommonError.accountInactive)
                        } else if !Config.shared.hasLease() || !Config.shared.leaseActive() {
                            self.log.v("No location selected")
                            onMain { self.syncUiWithConfig() }
                            Config.shared.setVpnEnabled(false)
                            return
                        } else {
                            self.vpn.changeGateway(lease: Config.shared.lease()!, gateway: Config.shared.gateway()!) { error, _ in onMain {
                                guard error == nil else {
                                    Config.shared.setVpnEnabled(false)
                                    return self.handleError(CommonError.failedVpn, cause: error)
                                }

                                self.expiration.update(Config.shared.lease())
                                self.recheckActiveLeaseAfterActivating()
                                self.log.v("User action: switchVpn: done")
                            }}
                        }
                    } else if !activate && Config.shared.hasGateway() {
                        self.vpn.disconnect { error, _ in onMain {
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

    func switchGateway(new: Gateway) {
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
                                return self.switchGateway(new: new)
                            }
                        } else {
                            return self.handleError(CommonError.failedFetchingData, cause: error)
                        }
                    }

                    Config.shared.setLease(lease!, new)

                    self.vpn.changeGateway(lease: lease!, gateway: new) { error, _ in
                        onMain {
                            guard error == nil else {
                                return self.handleError(CommonError.failedTunnel, cause: error)
                            }

                            self.expiration.update(Config.shared.lease())
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
               self.network.updateConfig(lease: nil, gateway: nil, done: { _, _ in })

               self.network.queryStatus { error, status in onMain {
                   guard let status = status else {
                        self.mainSwitch = false
                        self.working = false
                        return self.handleError(CommonError.failedTunnel, cause: error)
                   }

                    if status.active && status.hasGateway() {
                       self.vpn.disconnect { error, _ in onMain {
                           self.log.v("User action: turnVpnOffAfterExpired disconnected vpn, done")
                       }}
                   } else {
                       self.log.v("User action: turnVpnOffAfterExpired done")
                   }
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
        }

        self.vpnEnabled = Config.shared.vpnEnabled()
    }

    private func syncUiWithTunnel(done: @escaping Callback<NetworkStatus>) {
        self.log.v("Sync UI with NETX")
        self.network.queryStatus { error, status in onMain {
            guard let status = status else {
                self.log.v("  NETX not active".cause(error))
                self.mainSwitch = false
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
                    self.mainSwitch = true
                    Config.shared.setVpnEnabled(false)
                    self.working = false
                    return done(nil, status)
                }
            } else {
                self.log.v(" NETX inactive")
                self.mainSwitch = false
                Config.shared.setVpnEnabled(false)
                self.working = false
                return done(nil, status)
            }
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
        self.timerSeconds = seconds
        self.network.pause(seconds: seconds, done: { _, _ in })
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.timerSeconds = self.timerSeconds - 1
            if self.timerSeconds <= 0 {
                self.stopTimer()
                timer.invalidate()
            }
        }
    }

    var isPaused: Bool {
        return self.timerSeconds != 0
    }

    func stopTimer() {
        if self.timerSeconds != 0 {
            self.timerSeconds = 0
            self.network.pause(seconds: 0, done: { _, _ in })
        }
    }

    private let decoder = initJsonDecoder()
    func refreshAdsCounter(delay: Bool, ok: @escaping Ok<Void> = { _ in }) {
        // Delay so that we get some entries on the activity list without the need to re-enter the app
        bgThread.asyncAfter(deadline: .now() + TimeInterval(delay ? 3 : 0), execute: {
            self.network.sendMessage(msg: "stats", skipReady: false) { error, result in
                if error != nil {
                    return self.log.w("refreshAdsCounter: failed sending stats message".cause(error))
                }

                guard let stats = result else {
                    return self.log.e("refreshAdsCounter: could not read stats")
                }

                let jsonData = stats.data(using: .utf8)
                guard let json = jsonData else {
                    return self.log.e("refreshAdsCounter: failed getting json")
                }

                do {
                    let s = try self.decoder.decode(Stats.self, from: json)
                    onMain {
                        self.blockedCounter = Int(s.denied)
                        ActivityService.shared.setEntries(entries: s.entries)
                        ok(())
                    }
                } catch {
                    return self.log.e("refreshAdsCounter: Failed decoding account json".cause(error))
                }
            }
        })
    }

    private func shouldShowRateScreen() -> Bool {
        return self.blockedCounter >= 40 && !Config.shared.firstRun() && !Config.shared.rateAppShown()
    }
}
