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
import Factory

typealias Granted = Bool

class PermsRepo: Startable {

    var dnsProfilePerms: AnyPublisher<Granted, Never> {
        writeDnsProfilePerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }

    var notificationPerms: AnyPublisher<Granted, Never> {
        writeNotificationPerms.compactMap { $0 }.removeDuplicates().eraseToAnyPublisher()
    }
    
    @Injected(\.flutter) private var flutter
    @Injected(\.stage) private var stage
    @Injected(\.perm) private var perm
    @Injected(\.common) private var notification

    private lazy var dialog = Services.dialog
    private lazy var systemNav = Services.systemNav
    private lazy var netx = Services.netx

    private lazy var sheetRepo = stage

    private lazy var enteredForegroundHot = stage.enteredForegroundHot

    fileprivate let writeDnsProfilePerms = CurrentValueSubject<Granted?, Never>(nil)
    fileprivate let writeNotificationPerms = CurrentValueSubject<Granted?, Never>(nil)

    private var previousAccountType: AccountType? = nil
    private let bgQueue = DispatchQueue(label: "PermsRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    func start() {
        onForeground_checkNotificationPermsAndClearNotifications()
        onPurchaseSuccessful_showActivatedSheet()
        //onAccountTypeUpgraded_showActivatedSheet()
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
        .tryMap { _ in
            self.netx.createVpnProfile()
            return true
        }
        .eraseToAnyPublisher()
    }

    func askNotificationPerms() -> AnyPublisher<Granted, Error> {
        return notification.askForPermissions()
        .tryCatch { err in
            self.dialog.showAlert(
                message: L10n.notificationPermsDenied,
                header: L10n.notificationPermsHeader,
                okText: L10n.dnsprofileActionOpenSettings,
                okAction: { self.systemNav.openAppSettings() }
            )
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
            okAction: {
                let id = self.flutter.isFlavorFamily ? NOTIF_ONBOARDING_FAMILY : NOTIF_ONBOARDING
                self.notification.scheduleNotification(id: id, when: Date().addingTimeInterval(3))
                self.systemNav.openSystemSettings()
            }
        )
    }

    private func onForeground_checkNotificationPermsAndClearNotifications() {
        enteredForegroundHot
        .flatMap { _ in self.notification.getPermissions() }
        // When entering foreground also clear all notifications.
        // It's so that we do not clutter the lock screen.
        // We do have any notifications that need to stay after entering fg.
        .map { allowed in
            if allowed {
                //self.notification.clearAllNotifications()
            }
            return allowed
        }
        .sink(onValue: { it in self.writeNotificationPerms.send(it) })
        .store(in: &cancellables)
    }

    // Will display Activated sheet on successful purchase.
    // This will happen on any purchase by user or if necessary perms are missing.
    // It will ignore StoreKit auto restore if necessary perms are granted.
    private func onPurchaseSuccessful_showActivatedSheet() {
//        successfulPurchasesHot
//        .flatMap { it -> AnyPublisher<(Account, UserInitiated, Granted, Granted), Never> in
//            let (account, userInitiated) = it
//            return Publishers.CombineLatest4(
//                Just(account), Just(userInitiated),
//                self.dnsProfilePerms, self.vpnProfilePerms
//            )
//            .eraseToAnyPublisher()
//        }
//        .map { it -> Granted in
//            let (account, userinitiated, dnsAllowed, vpnAllowed) = it
//            if dnsAllowed && (account.type != "plus" || vpnAllowed) && !userinitiated {
//                return true
//            } else {
//                return false
//            }
//        }
//        .sink(onValue: { permsOk in
//            if !permsOk {
//                self.sheetRepo.stage.showModal(.Activated)
//            }
//        })
//        .store(in: &cancellables)
    }
//
//    // We want user to notice when they upgrade.
//    // From Libre to Cloud or Plus, as well as from Cloud to Plus.
//    // In the former case user will have to grant several permissions.
//    // In the latter case, probably just the VPN perm.
//    // If user is returning, it may be that he already has granted all perms.
//    // But we display the Activated sheet anyway, as a way to show that upgrade went ok.
//    // This will also trigger if StoreKit sends us transaction (on start) that upgrades.
//    private func onAccountTypeUpgraded_showActivatedSheet() {
//        accountTypeHot
//        .filter { now in
//            if self.previousAccountType == nil {
//                self.previousAccountType = now
//                return false
//            }
//
//            let prev = self.previousAccountType
//            self.previousAccountType = now
//
//            if prev == .Libre && now != .Libre {
//                return true
//            } else if prev == .Cloud && now == .Plus {
//                return true
//            } else {
//                return false
//            }
//        }
//        .sink(onValue: { _ in self.sheetRepo.showModal(.perms)} )
//        .store(in: &cancellables)
//    }

}
