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
import Combine
import Factory

class HomeViewModel: ObservableObject {
    private let log = BlockaLogger("Home")

    private lazy var permsRepo = Repos.permsRepo

    private var cancellables = Set<AnyCancellable>()

    @Injected(\.app) private var app
    @Injected(\.account) private var account
    @Injected(\.plus) private var plus
    @Injected(\.plusLease) private var plusLease
    @Injected(\.plusGateway) private var plusGateway
    @Injected(\.perm) private var perm
    @Injected(\.stage) private var stage

    private lazy var selectedGatewayHot = plusGateway.selected
    private lazy var selectedLeaseHot = plusLease.currentLease

    @Published var showSplash = true
    @Published var hideContent = false

    @Published var appState: AppState = .Deactivated
    @Published var vpnEnabled: Bool = false
    @Published var working: Bool = true

    @Published var dnsPermsGranted: Bool = false
    @Published var vpnPermsGranted: Bool = false
    @Published var notificationPermsGranted: Bool = false
    
    @Published var accountActive = false
    @Published var accountType = AccountType.Libre

    @Published var showError: Bool = false
    var errorHeader: String? = nil
    var error: String? = nil {
        didSet {
            if error != nil {
                showError = true
            } else {
                showError = false
                errorHeader = nil
                stage.onDismissed()
            }
        }
    }
    
    @Published var showInput: Bool = false

    var expiredAlertShown: Bool = false

    var onAccountExpired = {}


    @Published var timerSeconds: Int = 0

    @Published var selectedGateway: Gateway? = nil
    @Published var selectedLease: Lease? = nil

    var hasSelectedLocation : Bool {
        return accountActive && selectedGateway != nil
    }

    var location: String {
        return selectedGateway?.niceName() ?? "None"
    }

    var hasLease: Bool {
        return accountActive && selectedLease != nil
    }

    @Published var blockedCounter: Int = 0

    var encryptionLevel: Int {
        if working {
            return 1
        } else if appState == .Deactivated {
            return 1
        } else if !vpnEnabled {
            return 2
        } else {
            return 3
        }
    }

    
    init() {
        onErrorHeader()
        onError()
        onInput()
        onAppStateChanged()
        onWorking()
        onAccountTypeChanged()
        onPermsRepoChanged()
        onSelectedGateway()
        onSelectedLease()
        onVpnEnabled()
        onPauseUpdateTimer()
    }

//    private func onMajorErrorDisplayDialog() {
//        errorsHot.filter { it in it.major }
//        .map { it in "Error:  \(it)" }
//        .receive(on: RunLoop.main)
//        .sink(onValue: { it in self.error = it })
//        .store(in: &cancellables)
//    }

    private func onErrorHeader() {
        stage.errorHeader
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.errorHeader = it
        })
        .store(in: &cancellables)
    }

    private func onError() {
        stage.error
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.error = it?.localizedDescription
        })
        .store(in: &cancellables)
    }
    
    private func onInput() {
        stage.showInput
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.showInput = it
        })
        .store(in: &cancellables)
    }

    private func onAppStateChanged() {
        app.appStateHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.appState = it
        })
        .store(in: &cancellables)
    }

    private func onWorking() {
        app.workingHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.working = it
        })
        .store(in: &cancellables)
    }

    private func onAccountTypeChanged() {
        account.accountTypeHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.accountType = it
            self.accountActive = it.isActive()
        })
        .store(in: &cancellables)
    }

    private func onPermsRepoChanged() {
        permsRepo.dnsProfilePerms
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.dnsPermsGranted = it
        })
        .store(in: &cancellables)

        perm.vpnProfilePerms
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.vpnPermsGranted = it
        })
        .store(in: &cancellables)

        permsRepo.notificationPerms
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.notificationPermsGranted = it
        })
        .store(in: &cancellables)
    }

    private func onSelectedGateway() {
        selectedGatewayHot
        .map { it in it.gateway }
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.selectedGateway = it })
        .store(in: &cancellables)
    }

    private func onSelectedLease() {
        selectedLeaseHot
        .map { it in it.lease }
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.selectedLease = it })
        .store(in: &cancellables)
    }

    private func onVpnEnabled() {
        plus.plusEnabled
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.vpnEnabled = it })
        .store(in: &cancellables)
    }

    private func onPauseUpdateTimer() {
        app.pausedUntilHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            // Display the countdown only for short timers.
            // Long timer is the "backup" timer to remind user to unpause the app if
            // they "turn it off" in Cloud mode (the app cannot be fully turned of in
            // this mode, as we can't programatically deactivate the DNS profile.)
            if let it = it, let seconds = Calendar.current.dateComponents([.second], from: Date(), to: it).second, seconds <= 60 * 30 {
                return self.startTimer(seconds: seconds)
            }

            self.stopTimer()
        })
        .store(in: &cancellables)
    }

    func pause(seconds: Int?) {
        app.pauseApp(until: seconds)
        .receive(on: RunLoop.main)
        .sink(onFailure: { err in self.error = "\(err)" })
        .store(in: &cancellables)
    }

    func unpause() {
        app.unpauseApp()
        .receive(on: RunLoop.main)
        .sink(onFailure: { err in self.error = "\(err)" })
        .store(in: &cancellables)
    }

    func startTimer(seconds: Int) {
        self.log.v("startTimer: starting pause")
        self.timerSeconds = seconds
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
        } else {
            self.timerSeconds = 0
        }
    }

    func finishSetup() {
        self.permsRepo.askForAllMissingPermissions()
        .sink()
        .store(in: &cancellables)
    }

    func displayNotificationPermsInstructions() {
        self.permsRepo.displayNotificationPermsInstructions()
        .sink()
        .store(in: &cancellables)
    }

    func switchVpn(activate: Bool) {
        if activate {
            plus.switchPlus(active: true)
        } else {
            plus.switchPlus(active: false)
        }
    }

    /**
        Private methods used by those public entrypoints
    */

    private func handleError(_ error: CommonError, cause: Error? = nil) {
        onMain {
            self.log.e("\(error)".cause(cause))

            self.error = mapErrorForUser(error, cause: cause)
            self.working = false
        }
    }

    func showErrorMessage() -> String {
        if self.error?.count ?? 999 > 256 {
            return L10n.errorUnknown
        } else {
            return self.error!
        }
    }

}
