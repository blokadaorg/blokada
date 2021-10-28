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

class PaymentService {

    static let shared = PaymentService()

    private let log = Logger("Mock")
    private let api = BlockaApiService.shared

    var onChangeAccount = { (account: Account) in }

    private init() {
        // singleton
    }

    func refreshProductsAfterStart() {

    }

    func refreshProducts(ok: @escaping Ok<[Product]>, fail: @escaping Fail) {
        onBackground {
            self.log.v("Refresh products")
            sleep(3)
            onMain {
                let products = [
                    Product(id: "11", title: "6 Months", description: "Blokada Cloud", price: "14.99", period: 1, type: "cloud"),
                    Product(id: "1", title: "1 Month", description: "Blokada Plus", price: "9.99", period: 1, type: "plus"),
                    Product(id: "2", title: "6 Months", description: "Blokada Plus (XX per month. Save 10%)", price: "19.99", period: 6, type: "plus"),
                    Product(id: "3", title: "12 Months", description: "Blokada Plus (XX per month. Save 20%)", price: "39.99", period: 12, type: "plus")
                ]
                ok((products))
            }
        }
    }

    func buy(_ product: Product, ok: @escaping Ok<Void>, fail: @escaping Fail) {
        onBackground {
            self.log.v("Buy: \(product.id)")
            sleep(3)
            onMain {
                if Int.random(in: 1..<3) > 1 {
                    let request = AppleCheckoutRequest(
                        account_id: Config.shared.accountId(),
                        receipt: ""
                    )

                    self.api.postAppleCheckout(request: request) { error, account in
                        SharedActionsService.shared.updateAccount(account!)
                        onMain {
                            ok(())
                        }
                    }
                } else {
                    fail("Mocked error")
                }
            }
        }
    }

    func restoreTransaction(ok: @escaping Ok<Void>, fail: @escaping Fail) {
        onBackground {
            self.log.v("Restore transaction")
            sleep(1)
            self.log.v("Slept")
            onMain {
                ok(())
            }
        }
    }

    func cancelTransaction() {
        self.log.v("Cancel transaction")
    }

    func startObservingPayments() {
    }

    func stopObservingPayments() {
    }
}
