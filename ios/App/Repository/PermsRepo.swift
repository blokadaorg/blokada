//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine

typealias Granted = Bool

class PermsRepo {

    var dnsProfilePerms: AnyPublisher<Granted, Never> {
        writeDnsProfilePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var vpnProfilePerms: AnyPublisher<Granted, Never> {
        writeVpnProfilePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var notificationPerms: AnyPublisher<Granted, Never> {
        writeNotificationPerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    private lazy var notification = Services.notification
    private lazy var dialog = Services.dialog
    private lazy var systemNav = Services.systemNav

    private lazy var sheetRepo = Repos.sheetRepo
    private lazy var dnsProfileActivatedHot = Repos.cloudRepo.dnsProfileActivatedHot
    private lazy var enteredForegroundHot = Repos.stageRepo.enteredForegroundHot
    private lazy var successfulPurchasesHot = Repos.paymentRepo.successfulPurchasesHot

    fileprivate let writeDnsProfilePerms = CurrentValueSubject<Granted?, Never>(nil)
    fileprivate let writeVpnProfilePerms = CurrentValueSubject<Granted?, Never>(nil)
    fileprivate let writeNotificationPerms = CurrentValueSubject<Granted?, Never>(nil)

    private let bgQueue = DispatchQueue(label: "PermsRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    init() {
        onDnsProfileActivated()
        onForeground_checkNotificationPermsAndClearNotifications()
        onVpnPerms()
        onPurchaseSuccessful_showActivatedSheet()
    }

    func maybeDisplayDnsProfilePermsDialog() -> AnyPublisher<Ignored, Error> {
        return dnsProfilePerms.first()
        .tryMap { granted -> Ignored in
            if !granted {
                throw "show the dns profile dialog"
            } else {
                return true
            }
        }
        .tryCatch { _ in
            self.displayDnsProfilePermsInstructions()
            .tryMap { _ in throw "we never know if dns profile has been chosen" }
        }
        .eraseToAnyPublisher()
    }

    func askVpnProfilePerms() -> AnyPublisher<Granted, Error> {
        return Just(true)
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }

    func askNotificationPerms() -> AnyPublisher<Granted, Error> {
        return notification.askForPermissions()
        .tryCatch { err in
            self.dialog.showAlert(
                message: "You denied notifications. If you wish to change it, please use System Preferences.",
                header: L10n.activityInformationHeader,
                okText: L10n.universalActionContinue
            )
        }
        .eraseToAnyPublisher()
    }

    func askForAllMissingPermissions() -> AnyPublisher<Ignored, Error> {
        return sheetRepo.dismiss()
        .delay(for: 0.3, scheduler: self.bgQueue)
        .flatMap { _ in self.askNotificationPerms() }
        .tryCatch { err in
            // Notification perm is optional, ask for others
            return Just(true)
        }
        .flatMap { _ in self.askVpnProfilePerms() }
        .delay(for: 0.3, scheduler: self.bgQueue)
        .flatMap { _ in self.maybeDisplayDnsProfilePermsDialog() }
        // Show the activation sheet again to confirm user choices, and propagate error
        .tryCatch { err -> AnyPublisher<Ignored, Error> in
            return Just(true)
            .delay(for: 0.3, scheduler: self.bgQueue)
            .tryMap { _ -> Ignored in
                self.sheetRepo.showSheet(.Activated)
                throw err
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }

    func displayNotificationPermsInstructions() -> AnyPublisher<Ignored, Error> {
        return dialog.showAlert(
            message: L10n.notificationPermsDesc,
            header: L10n.notificationPermsHeader,
            okText: L10n.dnsprofileActionOpenSettings,
            okAction: { self.systemNav.openAppSettings() }
        )
    }

    private func displayDnsProfilePermsInstructions() -> AnyPublisher<Ignored, Error> {
        return dialog.showAlert(
            message: L10n.dnsprofileDesc,
            header: L10n.dnsprofileHeader,
            okText: L10n.dnsprofileActionOpenSettings,
            okAction: { self.systemNav.openSystemSettings() }
        )
    }

    private func onDnsProfileActivated() {
        dnsProfileActivatedHot
        .sink(onValue: { it in self.writeDnsProfilePerms.send(it) })
        .store(in: &cancellables)
    }

    private func onForeground_checkNotificationPermsAndClearNotifications() {
        enteredForegroundHot
        .flatMap { _ in self.notification.getPermissions() }
        // When entering foreground also clear all notifications.
        // It's so that we do not clutter the lock screen.
        // We do have any notifications that need to stay after entering fg.
        .map { allowed in
            if allowed {
                self.notification.clearAllNotifications()
            }
            return allowed
        }
        .sink(onValue: { it in self.writeNotificationPerms.send(it) })
        .store(in: &cancellables)
    }

    private func onVpnPerms() {
        // TODO: vpn perms
        self.writeVpnProfilePerms.send(true)
    }

    // Will display Activated sheet on successful purchase, if perms are not sufficient.
    // This means dns perms, and in case of Plus account, also vpn perms.
    // This will happen on first purchase, ie onboarding flow.
    // It may happen on app start when StoreKit sends a restored transactions to us.
    private func onPurchaseSuccessful_showActivatedSheet() {
        successfulPurchasesHot
        .flatMap { account in
            Publishers.CombineLatest3(
                Just(account), self.dnsProfilePerms, self.vpnProfilePerms
            )
        }
        .map { it -> Bool in
            let (account, dnsAllowed, vpnAllowed) = it
            if dnsAllowed && (account.type != "plus" || vpnAllowed) {
                return true
            } else {
                return false
            }
        }
        .sink(onValue: { permsOk in
            if !permsOk {
                self.sheetRepo.showSheet(.Activated)
            }
        })
        .store(in: &cancellables)
    }

}
