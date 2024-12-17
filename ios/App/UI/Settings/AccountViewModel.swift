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
import Combine
import Factory

class AccountViewModel: ObservableObject {

    @Published var account: JsonAccount?
    @Published var working: Bool = true
    @Published var showError: Bool = false
    @Published var selectedSettingsTab: String? = nil

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

    var type: AccountType {
        return mapAccountType(account?.type)
    }

    var activeUntil: String {
        return Strings.activeUntil(account)
    }

    private let log = BlockaLogger("Account")

    @Injected(\.account) private var accountRepo
    private var cancellables = Set<AnyCancellable>()

    init() {
        onAccountUpdated()
    }

    private func onAccountUpdated() {
        accountRepo.accountHot
        .receive(on: RunLoop.main)
        .sink(onValue: { it in self.account = it.account })
        .store(in: &cancellables)
    }

    func restoreAccount(_ newId: String, success: @escaping () -> Void) {
        accountRepo.restoreAccount(newId, completion: success)
    }

    func copyAccountIdToClipboard() {
        UIPasteboard.general.string = self.id
    }
   
    private func onError(_ error: CommonError, _ cause: Error? = nil) {
        self.log.e("\(error)".cause(cause))

        self.error = mapErrorForUser(error, cause: cause)
        self.working = false
    }

    func authenticate(ok: @escaping Ok<Void>, fail: @escaping Ok<Void>) {
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
                        ok(())
                    } else {
                        // there was a problem
                        fail(())
                    }
                }
            }
        } else {
            // no biometrics
            ok(())
        }
    }

    func selectSettings(_ settings: String) {
        selectedSettingsTab = settings
    }

}
