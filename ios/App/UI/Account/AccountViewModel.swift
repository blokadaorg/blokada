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
import LocalAuthentication

class AccountViewModel: ObservableObject {

    @Published var account: Account?
    @Published var working: Bool = true
    @Published var showError: Bool = false

    var error: String? = nil {
        didSet {
            if error != nil {
                showError = true
            }
        }
    }

    var active: Bool {
        return account?.isActive() ?? false
    }

    var id: String {
        return account?.id ?? ""
    }

    var type: String {
        return Strings.accountType(account)
    }

    var activeUntil: String {
        return Strings.activeUntil(account)
    }

    private let log = Logger("Account")

    private let api = BlockaApiService.shared
    private let vpn = VpnService.shared
    private let accountRepo = Repos.accountRepo

    init() {
        Config.shared.setOnAccountUpdated {
            self.syncConfig()
        }
    }

    init(mocked: String) {
        account = Account(id: mocked, active_until: "", active: false, type: "libre")
    }

    func openManageSubscriptions() {
        Links.openInBrowser(Links.manageSubscriptions())
    }

    func copyAccountIdToClipboard() {
        UIPasteboard.general.string = self.id
    }

    private func syncConfig() {
        onMain {
            if Config.shared.hasAccount() && Config.shared.hasKeys() {
                if self.account == nil || Config.shared.accountId() != self.account!.id {
                    self.account = Config.shared.account()
                } else if Config.shared.account()!.active_until != self.account!.active_until ?? nil {
                    self.account = Config.shared.account()
                }
            }
        }
    }

    func restoreAccount(_ newId: AccountId, success: @escaping () -> Void) {
        accountRepo.restoreAccount(newId)
        success()
    }

    private func setAccount(_ account: Account) {
        self.account = account
    }

    private func onError(_ error: CommonError, _ cause: Error? = nil) {
        self.log.e("\(error)".cause(cause))

        self.error = mapErrorForUser(error, cause: cause)
        self.working = false
    }

    func authenticate(ok: @escaping Ok<String>) {
        let context = LAContext()
        var error: NSError?

        // check whether biometric authentication is possible
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            // it's possible, so go ahead and use it
            let reason = L10n.accountUnlockToShow

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                // authentication has now completed
                DispatchQueue.main.async {
                    if success {
                        // authenticated successfully
                        ok(self.id)
                    } else {
                        // there was a problem
                    }
                }
            }
        } else {
            // no biometrics
            ok(self.id)
        }
    }
}
