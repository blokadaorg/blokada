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
import StoreKit
import Combine

class PaymentGatewayViewModel: ObservableObject {

    private let service = PaymentService.shared

    @Published var options = [PaymentViewModel]()

    @Published var working = false

    @Published var showError: Bool = false
    var error: String? = nil {
        didSet {
            showError = error != nil
        }
    }

    var accountActive: Bool {
        return Config.shared.accountActive()
    }

    func fetchOptions() {
        error = nil
        working = true

        service.refreshProducts(ok: { products in
            self.options = products.map { product in
                PaymentViewModel(product)
            }
            self.working = false
        }, fail: { error in
            self.working = false
            self.error = mapErrorForUser(CommonError.paymentFailed, cause: error)
        })
    }

    func buy(_ product: Product) {
        error = nil
        working = true
        service.buy(product, ok: { _ in
            self.working = false
        }, fail: { error in
            if error.isCommon(CommonError.paymentCancelled) {
                // No need to show error alert if user just cancelled
                self.error = nil
            } else {
                self.error = mapErrorForUser(CommonError.paymentFailed, cause: error)
            }
            self.working = false
        })
    }

    func cancel() {
        error = nil
        working = false
        self.service.cancelTransaction()
    }

    func restoreTransactions() {
        if error == nil {
            working = true
            service.restoreTransaction (ok: { _ in
                self.working = false
            }, fail: { error in
                self.working = false
                self.error = mapErrorForUser(CommonError.paymentFailed, cause: error)
            })
        }
    }

    func showTerms() {
        Links.openInBrowser(Links.tos())
    }

    func showPrivacy() {
        Links.openInBrowser(Links.privacy())
    }

    func showSupport() {
        Links.openInBrowser(Links.support())
    }

}
