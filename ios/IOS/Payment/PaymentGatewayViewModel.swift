//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
