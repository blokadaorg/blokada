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

    private let log = BlockaLogger("Account")

    private var cancellables = Set<AnyCancellable>()

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
