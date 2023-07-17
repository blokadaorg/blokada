//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import Foundation
import Factory
import Combine
import StoreKit

class AccountPaymentBinding: AccountPaymentOps {
    var products = CurrentValueSubject<[Product], Never>([])
    var status = CurrentValueSubject<PaymentStatus, Never>(.unknown)

    @Injected(\.flutter) private var flutter
    @Injected(\.commands) private var commands

    private lazy var storeKit = StoreKitWrapper.shared

    init() {
        AccountPaymentOpsSetup.setUp(binaryMessenger: flutter.getMessenger(), api: self)
        _onStoreKitOngoingTransaction()
    }

    func refreshProducts() {
        commands.execute(.fetchProducts)
    }

    func restorePurchase() {
        commands.execute(.restorePayment)
    }

    func buyProduct(_ productId: String) {
        // TODO: buyproduct loop?
        // StoreKit may return a restored transaction that hasn't been consumed yet.
        // However, there might be many restored transactions that it gives us.
        // So we repeat until it gives them but, we can't get an active account.

        commands.execute(.purchase, productId)
    }

    func startObservingPayments() {
        self.storeKit.startObservingPayments()
    }

    func stopObservingPayments() {
        self.storeKit.stopObservingPayments()
    }

    func cancelTransaction() {
        self.storeKit.finishPurchase()
    }

    func doArePaymentsAvailable(completion: @escaping (Result<Bool, Error>) -> Void) {
        completion(Result.success(SKPaymentQueue.canMakePayments()))
    }

    func doFetchProducts(completion: @escaping (Result<[Product], Error>) -> Void) {
        self.storeKit.fetchProducts(
            ok: { it in
                let products = it.map { it in return Product(
                    id: it.productIdentifier,
                    title: it.localTitle,
                    description: it.localDescription,
                    price: it.localPrice,
                    pricePerMonth: "", // TODO use this?
                    periodMonths: Int64(it.durationMonths),
                    type: (it.productIdentifier.starts(with: "cloud") ? "cloud" : "plus"),
                    trial: it.isTrial,
                    owned: false
                ) }
                completion(.success(products))
            },
            fail: { err in completion(.failure(err)) }
        )
    }

    func doPurchaseWithReceipt(productId: String, completion: @escaping (Result<String, Error>) -> Void) {
        self.storeKit.purchase(productId: productId, ok: { _ in
            self._getReceipt(completion: completion)
        }, fail: { err in completion(.failure(err))} )
    }

    func doRestoreWithReceipt(completion: @escaping (Result<String, Error>) -> Void) {
        self.storeKit.restorePurchase(
            ok: { _ in self._getReceipt(completion: completion) },
            fail: { err in
                // Try getting the receipt anyway, StoreKit seems very finnicky about the states.
                self._getReceipt(completion: completion)
            }
        )
    }

    func doChangeProductWithReceipt(productId: String, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure("Not available on iOS"))
    }

    func doProductsChanged(products: [Product], completion: @escaping (Result<Void, Error>) -> Void) {
        self.products.send(products)
        completion(.success(()))
    }
 
    func doPaymentStatusChanged(status: PaymentStatus, completion: @escaping (Result<Void, Error>) -> Void) {
        self.status.send(status)
        completion(Result.success(()))
    }

    func doFinishOngoingTransaction(completion: @escaping (Result<Void, Error>) -> Void) {
        self.storeKit.finishPurchase()
        completion(.success(()))
    }

    // A purchase can be initiated in one of many ways (explicit buy action from user,
    // a pending transaction from StoreKit, a restore purchase action from user etc).
    // We need a receipt for it to be processed by the backend.
    private func _getReceipt(completion: @escaping (Result<String, Error>) -> Void) {
        // First, get the receipt of the pending transaction.
        let receipt = self.storeKit.getReceipt()
        if let it = receipt {
            return completion(.success(it))
        }

        // Try refreshing receipt if unavailable - just StoreKit things
        self.storeKit.refreshReceipt(
            ok: { it in
                guard let receipt = self.storeKit.getReceipt() else {
                    return completion(.failure("receipt nil after refresh"))
                }

                return completion(.success(receipt))
            },
            fail: { err in
                return completion(.failure(err))
            }
        )
    }

    private func _onStoreKitOngoingTransaction() {
        storeKit.onOngoingTransaction = {
            self._getReceipt(completion: { result in
                switch (result) {
                case .success(let it):
                    self.commands.execute(.receipt, it)
                    break
                case .failure(let err):
                    print("onStoreKitOngoingTransation error: \(err)")
                    break
                }
            })
        }
    }
}

extension Container {
    var payment: Factory<AccountPaymentBinding> {
        self { AccountPaymentBinding() }.singleton
    }
}
