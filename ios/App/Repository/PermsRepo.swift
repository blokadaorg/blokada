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

    fileprivate let writeDnsProfilePerms = CurrentValueSubject<Granted?, Never>(nil)
    fileprivate let writeVpnProfilePerms = CurrentValueSubject<Granted?, Never>(nil)
    fileprivate let writeNotificationPerms = CurrentValueSubject<Granted?, Never>(nil)

    private let bgQueue = DispatchQueue(label: "PermsRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    init() {
        onDnsProfileActivated()
        onForeground_checkNotificationPerms()
        onVpnPerms()
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
        .catch { _ in self.displayDnsProfilePermsInstructions() }
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
            self.dialog.showAlert(message: "You denied notifications. If you wish to change it, please use System Preferences.")
        }
        .eraseToAnyPublisher()
    }

    func askForAllMissingPermissions() -> AnyPublisher<Ignored, Error> {
        return sheetRepo.dismiss()
        .flatMap { _ in self.askNotificationPerms() }
        .tryCatch { err in
            // Notification perm is optional, ask for others
            return Just(true)
        }
        .flatMap { _ in self.askVpnProfilePerms() }
        .delay(for: 1.0, scheduler: self.bgQueue)
        .flatMap { _ in
            self.displayDnsProfilePermsInstructions()
            .tryMap { _ in throw "we never know if dns profile has been chosen" }
        }
        // Show the activation sheet again to confirm user choices, and propagate error
        .tryCatch { err -> AnyPublisher<Ignored, Error> in
            return Just(true)
            .delay(for: 1.0, scheduler: self.bgQueue)
            .tryMap { _ -> Ignored in
                self.sheetRepo.showSheet(.Activated)
                throw err
            }
            .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
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

    private func onForeground_checkNotificationPerms() {
        enteredForegroundHot
        .flatMap { _ in self.notification.getPermissions() }
        .sink(onValue: { it in self.writeNotificationPerms.send(it) })
        .store(in: &cancellables)
    }

    private func onVpnPerms() {
        // TODO: vpn perms
        self.writeVpnProfilePerms.send(true)
    }

}
