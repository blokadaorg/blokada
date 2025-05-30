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
    let errorHeader = CurrentValueSubject<String?, Never>(nil)
    let error = CurrentValueSubject<Error?, Never>(nil)

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
            self.commands.cmd.onCommand(command: "\(CommandName.modalDismiss)", m: 2) { _ in
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

    var supportedSheets: [StageModal] = [
        .plusLocationSelect, .accountChange
    ]

    func doShowModal(modal: StageModal, completion: @escaping (Result<Void, Error>) -> Void) {
//    if (modal == .pause) {
//        currentModal.send(nil)
//        showPauseMenu.send(true)
//    } else

        errorHeader.send(nil)

        if supportedSheets.contains(modal) {
            currentModal.send(modal)
        } else if (modal == .fault) {
            error.send(L10n.errorUnknown)
        } else if (modal == .faultLocked) {
            error.send(L10n.errorLocked)
        } else if (modal == .faultLockInvalid) {
            //error.send(L10n.errorLockInvalid)
        } else if (modal == .faultLinkAlready) {
            error.send(L10n.familyFaultLinkAlready)
        } else if (modal == .accountInitFailed) {
            error.send(L10n.errorUnknown)
        } else if (modal == .accountRestoreFailed) {
            error.send(L10n.errorPaymentInactiveAfterRestore)
        } else if (modal == .accountRestoreIdOk) {
            errorHeader.send(L10n.paymentHeaderActivated)
            error.send(L10n.genericAccountActive)
        } else if (modal == .accountRestoreIdFailed) {
            error.send(L10n.errorAccountInactiveAfterRestore)
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

    func doOpenLink(url: String, completion: @escaping (Result<Void, Error>) -> Void) {
        if let link = URL(string: url) {
          UIApplication.shared.open(link)
        }
        completion(.success(()))
    }

    func doHomeReached(completion: @escaping (Result<Void, any Error>) -> Void) {
        // not used on ios
        completion(.success(()))
    }
}

extension Container {
    var stage: Factory<StageBinding> {
        self { StageBinding() }.singleton
    }
}
