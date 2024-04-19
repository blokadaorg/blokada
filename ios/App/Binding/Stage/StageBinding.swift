//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Factory
import Combine
import UIKit

extension StageModal: Identifiable {
    var id: Int {
        rawValue
    }
}

class StageBinding: StageOps {
    let enteredForegroundHot = CurrentValueSubject<Bool?, Never>(nil)
    let currentModal = CurrentValueSubject<StageModal?, Never>(nil)
    let showPauseMenu = CurrentValueSubject<Bool, Never>(false)
    let error = CurrentValueSubject<Error?, Never>(nil)

    let activeTab = CurrentValueSubject<Tab, Never>(Tab.Home)
    let tabPayload = CurrentValueSubject<String?, Never>(nil)

    let showNavbar = CurrentValueSubject<Bool, Never>(false)
    let showInput = CurrentValueSubject<Bool, Never>(false)
    
    let netx = Services.netx

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    func setTab(_ tab: Tab) {
        commands.execute(.route, "\(tab.rawValue.lowercased())")
    }

    func setRoute(_ path: String) {
        commands.execute(.route, path)
    }

    func setTabPayload(_ payload: String) {
        commands.execute(.route, "\(activeTab.value.rawValue.lowercased())/\(payload)")
    }

    func onForeground(_ foreground: Bool) {
        enteredForegroundHot.send(foreground)
        if foreground {
            commands.execute(.foreground)
            netx.refreshOnForeground() // TODO: a better place
        } else {
            commands.execute(.background)
        }
    }
    
    func showModal(_ modal: StageModal, params: Any? = nil) {
        commands.execute(.modalShow, "\(modal)")
    }

    func dismiss() -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            self.commands.cmd.onCommand(command: "\(CommandName.modalDismiss)") { _ in
                return promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }

    func onDismissed() {
        commands.execute(.modalDismissed)
    }

    func showPauseMenu(_ show: Bool) {
        if (show) {
            commands.execute(.modalShow, "pause")
        } else {
            commands.execute(.modalDismissed)
        }
    }

    init() {
        StageOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
    }

    func doRouteChanged(path: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if path.isEmpty {
            // Just background, ignore
            return;
        }

        let parts = path.components(separatedBy: "/")
        activeTab.send(mapTabIdToTab(parts[0]))
        if parts.count > 1 && !parts[1].isEmpty {
            tabPayload.send(parts[1])
        } else {
            tabPayload.send(nil)
        }
        completion(.success(()))
    }

    var supportedSheets: [StageModal] = [
        .custom, .help, .perms, .payment, .plusLocationSelect,
        .adsCounterShare, .accountChange, .accountLink,
        .onboardingAccountDecided
    ]

    func doShowModal(modal: StageModal, completion: @escaping (Result<Void, Error>) -> Void) {
//    if (modal == .pause) {
//        currentModal.send(nil)
//        showPauseMenu.send(true)
//    } else
        if supportedSheets.contains(modal) {
            currentModal.send(modal)
        } else if (modal == .fault) {
            error.send(L10n.errorUnknown)
        } else if (modal == .faultLocked) {
            error.send(L10n.errorLocked)
        } else if (modal == .faultLockInvalid) {
            //error.send(L10n.errorLockInvalid)
        } else if (modal == .accountInitFailed) {
            error.send(L10n.errorUnknown)
        } else if (modal == .accountRestoreFailed) {
            error.send(L10n.errorPaymentInactiveAfterRestore)
        } else if (modal == .accountExpired) {
            //error.send(L10n.errorAccountInactiveGeneric)
        } else if (modal == .plusTooManyLeases) {
            error.send(L10n.errorVpnTooManyLeases)
        } else if (modal == .plusVpnFailure) {
            error.send(L10n.errorVpn)
        } else if (modal == .paymentUnavailable) {
            error.send(L10n.errorPaymentNotAvailable)
        } else if (modal == .paymentTempUnavailable) {
            error.send(L10n.errorPaymentFailed)
        } else if (modal == .paymentFailed) {
            error.send(L10n.errorPaymentFailedAlternative)
        } else if (modal == .accountInvalid) {
            error.send(L10n.errorAccountInvalid)
        } else if (modal == .deviceAlias) {
            showInput.send(true)
        } else {
            currentModal.send(nil)
        }
        completion(.success(()))
        commands.execute(.modalShown, "\(modal)")
    }
    
    func doDismissModal(completion: @escaping (Result<Void, Error>) -> Void) {
        if currentModal.value != nil {
            currentModal.send(nil)
            //showPauseMenu.send(false)
            completion(.success(()))
            commands.execute(.modalDismissed)
        } else if error.value != nil {
            error.send(nil)
            completion(.success(()))
            commands.execute(.modalDismissed)
        } else if showInput.value {
            showInput.send(false)
            completion(.success(()))
            commands.execute(.modalDismissed)
        } else {
            //showPauseMenu.send(false)
            completion(.success(()))
            commands.execute(.modalDismissed)
        }
    }

    func doShowNavbar(show: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        showNavbar.send(show)
        completion(.success(()))
    }

    func doOpenLink(url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let link = URL(string: url) {
          UIApplication.shared.open(link)
        }
        completion(.success(()))
    }
}

extension Container {
    var stage: Factory<StageBinding> {
        self { StageBinding() }.singleton
    }
}
