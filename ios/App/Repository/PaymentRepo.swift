//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import Combine
import StoreKit

class PaymentRepo: Startable {

    var productsHot: AnyPublisher<[Product], Never> {
        self.writeProducts.compactMap { $0 }.eraseToAnyPublisher()
    }

    var successfulPurchasesHot: AnyPublisher<(Account, UserInitiated), Never> {
        self.writeSuccessfulPurchases.compactMap { $0 }.eraseToAnyPublisher()
    }

    fileprivate let writeProducts = CurrentValueSubject<[Product]?, Never>(nil)
    fileprivate let writeSuccessfulPurchases = CurrentValueSubject<(Account, UserInitiated)?, Never>(nil)

    fileprivate let refreshProductsT = SimpleTasker<Ignored>("refreshProducts")
    fileprivate let restorePurchaseT = SimpleTasker<Ignored>("restorePurchase")
    fileprivate let buyProductT = Tasker<ProductId, Ignored>("buyProduct")
    fileprivate let consumePurchaseT = Tasker<UserInitiated, Ignored>("consumePurchase", debounce: 0.0)

    private lazy var processingRepo = Repos.processingRepo
    private lazy var stageRepo = Repos.stageRepo
    private lazy var accountRepo = Repos.accountRepo

    private lazy var api = Services.apiForCurrentUser
    private lazy var storeKit = StoreKitWrapper.shared
    private lazy var storeKit2 = Services.storeKit

    private let bgQueue = DispatchQueue(label: "PaymentRepoBgQueue")
    private var cancellables = Set<AnyCancellable>()

    func start() {
        onRefreshProducts()
        onBuyProduct()
        onRestorePurchase()
        onConsumePurchase()
        onStoreKitOngoingTransaction()
        onStageChangeObservePayments()
        refreshProducts() // Refresh products on init automatically
    }

    // Will ask StoreKit to refresh the products list used in the payments screen.
    func refreshProducts() -> AnyPublisher<Bool, Error> {
        return refreshProductsT.send()
    }

    func restorePurchase() -> AnyPublisher<Bool, Error> {
        return restorePurchaseT.send()
    }

    func buyProduct(_ productId: String) -> AnyPublisher<Bool, Error> {
        return buyProductT.send(productId)
    }

    func cancelTransaction() {
        self.storeKit.finishPurchase()
    }

    private func onRefreshProducts() {
        refreshProductsT.setTask { _ in Just(true)
            .flatMap { _ in
                //self.storeKit2.fetchSKProducts()
                Future<[SKProduct], Error> { promise in
                    self.storeKit.fetchProducts(
                        ok: { it in return promise(.success(it)) },
                        fail: { err in return promise(.failure(err)) }
                    )
                }
            }
            .tryMap { products -> [Product] in
                products.map { it in return Product(
                    id: it.productIdentifier,
                    title: it.localTitle,
                    description: it.localDescription,
                    price: it.localPrice,
                    period: it.durationMonths,
                    type: (it.productIdentifier.starts(with: "cloud") ? "cloud" : "plus"),
                    trial: it.isTrial
                ) }
            }
            .tryMap { it -> Bool in
                self.writeProducts.send(it)
                return true
            }
            .eraseToAnyPublisher()
        }
    }

    private func onRestorePurchase() {
        restorePurchaseT.setTask { it in Just(true)
            .flatMap { _ in
                Future<Void, Error> { promise in
                    self.storeKit.restorePurchase(
                        ok: { it in return promise(.success(())) },
                        fail: { err in return promise(.failure(err)) }
                    )
                }
            }
            .flatMap { _ in
                self.consumePurchaseT.send(true)
            }
            .tryCatch { err in
                // Try finishing transaction anyway, StoreKit seems very finnicky about the states.
                // This will also cause a request to our backend, which may have already activated.
                self.consumePurchaseT.send(true)
            }
            .eraseToAnyPublisher()
        }
    }
    
    private func onBuyProduct() {
        buyProductT.setTask { productId in Just(productId)
            // Ask StoreKit to make the purchase
            .flatMap { productId in
                Future<Bool, Error> { promise in
                    self.storeKit.purchase(productId: productId, ok: { restored in
                        return promise(.success(restored))
                    }, fail: { err in
                        return promise(.failure(err))
                    })
                }
            }
            // Consume this transaction
            .flatMap { restored in
                self.consumePurchaseT.send(true)
            }
            // StoreKit may return a restored transaction that hasn't been consumed yet.
            // However, there might be many restored transactions that it gives us.
            // So we repeat until it gives them but, we can't get an active account.
            .tryCatch { err -> AnyPublisher<Bool, Error> in
                if let err = err as? CommonError, err == CommonError.paymentInactiveAfterRestore {
                    BlockaLogger.w("PaymentRepo", "Pulling another restored transaction if any")
                    return self.buyProductT.send(productId)
                } else {
                    // Try finishing transaction anyway, StoreKit seems very finnicky.
                    return self.consumePurchaseT.send(true)
                }
            }
            .eraseToAnyPublisher()
        }
    }

    // A purchase can be initiated in one of many ways (explicit buy action from user,
    // a pending transaction from StoreKit, a restore purchase action from user etc).
    // Eventually a pending transaction is consumed here.
    private func onConsumePurchase() {
        consumePurchaseT.setTask { userInitiated -> AnyPublisher<Bool, Error> in
            // First, get the receipt of the pending transaction.
            Just(self.storeKit.getReceipt())
            // Try refreshing receipt if unavailable - just StoreKit things
            .flatMap { it -> AnyPublisher<String, Error> in
                guard let it = it else {
                    return Future<String, Error> { promise in
                        self.storeKit.refreshReceipt(
                            ok: { it in
                                guard let receipt = self.storeKit.getReceipt() else {
                                    return promise(.failure("receipt nil after refresh"))
                                }
                                return promise(.success(receipt))
                            },
                            fail: { err in return promise(.failure(err)) }
                        )
                    }
                    .eraseToAnyPublisher()
                }

                return Just(it).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
            // Post it to our backend for verification, receive new account object
            .flatMap { receipt in self.api.postAppleCheckoutForCurrentUser(receipt) }
            // Refresh account with backend to make sure it is considered active
            .flatMap { account in self.accountRepo.restoreAccount(account.id) }
            .tryMap { account -> Account in
                if !account.isActive() {
                    throw CommonError.accountInactiveAfterRestore
                } else {
                    return account
                }
            }
            .tryMap { account -> Bool in
                self.storeKit.finishPurchase()
                self.writeSuccessfulPurchases.send((account, userInitiated))
                return true
            }
            .tryCatch { err -> AnyPublisher<Bool, Error> in
                self.storeKit.finishPurchase()
                throw err
            }
            .eraseToAnyPublisher()
        }
    }

    private func onStoreKitOngoingTransaction() {
        storeKit.onOngoingTransaction = {
            // Only restore implicitly if current account is not active
            self.accountRepo.accountTypeHot.first()
            .filter { it in it == .Libre }
            .sink (onValue: { _ in
                self.consumePurchaseT.send(false)
            })
            .store(in: &self.cancellables)
        }
    }

    private func onStageChangeObservePayments() {
        stageRepo.creatingHot
        .sink(onValue: { _ in self.storeKit.startObservingPayments() })
        .store(in: &cancellables)
    
        stageRepo.destroyingHot
        .sink(onValue: { _ in self.storeKit.stopObservingPayments() })
        .store(in: &cancellables)
    }

}

typealias UserInitiated = Bool
