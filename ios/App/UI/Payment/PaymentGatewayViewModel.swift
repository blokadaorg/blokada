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
import Factory

class PaymentGatewayViewModel: ObservableObject {
    @Injected(\.payment) private var payment

    private var cancellables = Set<AnyCancellable>()

    @Published var options = [PaymentViewModel]()

    @Published var working = false

    @Published var showError: Bool = false
    var error: String? = nil {
        didSet {
            showError = error != nil
        }
    }

    init() {
        onProductsChanged()
        onStatusChanged()
    }

    init(mocked: Bool) {
        self.options = [
            PaymentViewModel("Product 1"),
            PaymentViewModel("Product 2"),
            PaymentViewModel("Cloud Product 3")
        ]
    }

//    var accountActive: Bool {
//        return Config.shared.accountActive()
//    }

    func fetchOptions() {
        error = nil
        working = true
        payment.refreshProducts()
    }

    func buy(_ product: Product) {
        error = nil
        working = true

        payment.buyProduct(product.id)
//        .receive(on: RunLoop.main)
//        .sink(
//            onFailure: { error in
//                if error.isCommon(CommonError.paymentCancelled) {
//                    // No need to show error alert if user just cancelled
//                    self.error = nil
//                } else {
//                    self.error = mapErrorForUser(CommonError.paymentFailed, cause: error)
//                }
//                self.working = false
//            },
//            onSuccess: { self.working = false }
//        )
//        .store(in: &cancellables) // TODO: should hold for cold publishers?
    }

    func cancel() {
        error = nil
        working = false
        payment.cancelTransaction()
    }

    func restoreTransactions() {
        if error == nil {
            working = true

            payment.restorePurchase()
//            .receive(on: RunLoop.main)
//            .sink(
//                onFailure: { err in
//                    self.error = mapErrorForUser(CommonError.paymentFailed, cause: err)
//                    self.working = false
//                },
//                onSuccess: { self.working = false }
//            )
//            .store(in: &cancellables) // TODO: should hold for cold publishers?
        }
    }

    private func onStatusChanged() {
        payment.status
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            switch (it) {
            case .ready:
                self.working = false
                break
            case .fetching:
                fallthrough
            case .restoring:
                fallthrough
            case .purchasing:
                self.working = true
                break
            case .unknown:
                self.working = false
            case .fatal:
                self.working = false
                self.error = "fatal"
            }
        })
        .store(in: &cancellables)
    }

    private func onProductsChanged() {
        payment.products
        .receive(on: RunLoop.main)
        .sink(onValue: { it in
            self.options = it.map { p in PaymentViewModel(p) }
            self.working = false
        })
        .store(in: &cancellables)
    }
}
