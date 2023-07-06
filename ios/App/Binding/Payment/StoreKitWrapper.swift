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

import StoreKit
import Foundation

class StoreKitWrapper: NSObject, SKProductsRequestDelegate, SKRequestDelegate,
        SKPaymentTransactionObserver {

    private let productIdentifiers = [
        "plus_month",
        "cloud_12month",
        "plus_12month",
    ]

    private let log = BlockaLogger("StoreKit")

    private var products = [SKProduct]()

    private var productRequest: SKProductsRequest!

    private var ongoingTransaction = Atomic<SKPaymentTransaction?>(nil)

    private var productsWaiting = Atomic<Cb<[SKProduct]>?>(nil)
    private var purchaseWaiting = Atomic<Cb<TransactionRestored>?>(nil)
    private var restoreWaiting = Atomic<Cb<Void>?>(nil)
    private var refreshReceiptWaiting = Atomic<Cb<Void>?>(nil)

    private override init() {
        // singleton
    }

    static let shared: StoreKitWrapper = StoreKitWrapper()

    // Called when a transaction comes from StoreKit but no handler is set waiting
    var onOngoingTransaction = {}

    func fetchProducts(ok: @escaping Ok<[SKProduct]>, fail: @escaping Faile) {
        onBackground {
            guard SKPaymentQueue.canMakePayments() else {
                return fail(CommonError.paymentNotAvailable)
            }

            guard self.productsWaiting.value == nil else {
                self.productsWaiting.value = Cb(ok: ok, fail: fail)
                return
            }

            guard self.products.isEmpty else {
                self.log.v("Returning cached products")
                return ok(self.products)
            }

            self.productsWaiting.value = Cb(ok: ok, fail: fail)

            let productRequest = SKProductsRequest(productIdentifiers: Set(self.productIdentifiers))
            productRequest.delegate = self
            productRequest.start()
        }
    }

    func purchase(productId: ProductId, ok: @escaping Ok<TransactionRestored>, fail: @escaping Faile) {
        onBackground {
            guard self.purchaseWaiting.value == nil else {
                self.purchaseWaiting.value = Cb(ok: ok, fail: fail)
                return
            }

            guard let product = self.products.first(where: { p in p.productIdentifier == productId }) else {
                return fail("Payment: product with id \(productId) not found")
            }

            self.purchaseWaiting.value = Cb(ok: ok, fail: fail)
            let payment = SKMutablePayment(product: product)
            SKPaymentQueue.default().add(payment)
            self.log.v("Added \(product.productIdentifier) to queue")
        }
    }

    func finishPurchase() {
        onBackground {
            guard let t = self.ongoingTransaction.value else {
                //self.log.w("Tried to finish transaction, but nothing ongoing")
                return
            }

            self.ongoingTransaction.value = nil
            SKPaymentQueue.default().finishTransaction(t)
            self.log.v("finishPurchase: called StoreKit")
        }
    }

    func restorePurchase(ok: @escaping Ok<Void>, fail: @escaping Faile) {
        onBackground {
            guard self.restoreWaiting.value == nil else {
                self.restoreWaiting.value = Cb(ok: ok, fail: fail)
                return
            }

            self.restoreWaiting.value = Cb(ok: ok, fail: fail)
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }

    func hasOngoingPurchase() -> Bool {
        return ongoingTransaction.value != nil
    }

    func getReceipt() -> String? {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
            FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {

            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let receiptString = receiptData.base64EncodedString(options: [])
                return receiptString
            } catch {
                self.log.e("Could not read receipt".cause(error))
                return nil
            }
        } else {
            self.log.e("Did not find receipt on storage")
            return nil
        }
    }

    func refreshReceipt(ok: @escaping Ok<Void>, fail: @escaping Faile) {
        guard self.refreshReceiptWaiting.value == nil else {
            self.refreshReceiptWaiting.value = Cb(ok: ok, fail: fail)
            return
        }

        self.refreshReceiptWaiting.value = Cb(ok: ok, fail: fail)

        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }

    func startObservingPayments() {
        BlockaLogger.v("StoreKit", "Starting observing payments")
        SKPaymentQueue.default().add(self)
    }

    func stopObservingPayments() {
        SKPaymentQueue.default().remove(self)
    }

    // Called when the product request succeeded.
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        onBackground {
            if !response.products.isEmpty {
                self.products = response.products.sorted { a, b in
                    a.durationMonths < b.durationMonths
                }
            }

            let callback = self.productsWaiting.value
            guard let done = callback else {
                return self.log.e("No waiting callback")
            }

            self.productsWaiting.value = nil

            if self.products.isEmpty {
                self.log.e("Products request returned no products")
                done.fail(CommonError.paymentNotAvailable)
            } else {
                self.log.v("Products received")
                done.ok(self.products)
            }
        }
    }

    // Called when the receipt refresh request succeeded
    func requestDidFinish(_ request: SKRequest) {
        onBackground {
            self.log.v("Receipt refreshed")

            let callback = self.refreshReceiptWaiting.value
            guard let done = callback else {
                self.log.w("No callback waiting for the receipt, calling the default callback")
                self.onOngoingTransaction()
                return
            }

            self.refreshReceiptWaiting.value = nil
            done.ok(())
        }
    }

    // Called when the product or receipt refresh request failed.
    func request(_ request: SKRequest, didFailWithError error: Error) {
        onBackground {
            let callback = self.productsWaiting.value
            guard let done = callback else {
                let callback = self.refreshReceiptWaiting.value
                guard let done = callback else {
                    return self.log.e("No waiting callback, request failed".cause(error))
                }

                self.refreshReceiptWaiting.value = nil
                return done.fail(error)
            }

            self.productsWaiting.value = nil
            done.fail(error)
        }
    }

    // The main StoreKit callback for purchasing and restoring transactions
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        onBackground {
            if transactions.count > 1 && (transactions[0].transactionState == .restored || transactions[0].transactionState == .purchased) {
                // To not be spammy towards API, assume all transactions are of restored type, and only send the most recent
                let sorted = transactions.sorted { $0.transactionDate ?? Date(timeIntervalSince1970: 0) < $1.transactionDate ?? Date(timeIntervalSince1970: 0) }
                let mostRecent = sorted.last!
                self.log.v("Received several transactions, using most recent: " + mostRecent.brief())

                // Imediatelly finish older transactions
                sorted.dropLast().forEach {
                    SKPaymentQueue.default().finishTransaction($0)
                }
                self.transactionReady(nil, mostRecent)
                return
            }

            for transaction in transactions {
                self.log.v("paymentQueue: update: " + transaction.brief())
                switch transaction.transactionState {
                case .purchasing: break
                case .deferred: self.log.w("paymentUpdate: deferred")
                case .purchased:
                    self.transactionReady(nil, transaction)
                case .failed:
                    self.transactionReady(transaction.error, transaction)
                case .restored:
                    self.transactionReady(transaction.error, transaction)
                @unknown default:
                    self.log.w("paymentUpdate: unknown")
                    self.transactionReady(transaction.error, transaction)
                }
            }
        }
    }

    // Called when transaction is ready to be finalized (success or error).
    func transactionReady(_ error: Error?, _ transaction: SKPaymentTransaction) {
        let callback = self.purchaseWaiting.value
        guard let done = callback else {
            // No purchaseWaiting callback means, app start or restoring transactions
            if error == nil {
                let previous = self.ongoingTransaction.value
                if previous?.date() ?? Date(timeIntervalSince1970: 0) < transaction.date() {
                    self.log.v("Set transaction as ongoing: " + (transaction.transactionIdentifier ?? "nil"))
                    self.ongoingTransaction.value = transaction

                    if let older = previous {
                        SKPaymentQueue.default().finishTransaction(older)
                    }

                    if self.restoreWaiting.value == nil {
                        self.log.v("No callback waiting for this transaction, calling the default callback")
                        self.onOngoingTransaction()
                    }
                } else {
                    SKPaymentQueue.default().finishTransaction(transaction)
                }
            } else {
                self.log.w("Finishing errored transaction".cause(error))
                SKPaymentQueue.default().finishTransaction(transaction)
            }
            return
        }

        self.ongoingTransaction.value = transaction
        self.purchaseWaiting.value = nil

        if let error = error {
            done.fail(error)
        } else {
            done.ok(false)
        }
    }

    // Called when all restorable transactions have been processed by the payment queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        let callback = self.restoreWaiting.value
        guard let done = callback else {
            return
        }

        self.restoreWaiting.value = nil

        // Restoring ended, notify the callback about what we got
        if self.ongoingTransaction.value == nil {
            return done.fail("Found no payment to be restored")
        } else {
            return done.ok(())
        }
    }

    // Called when an error occurred while restoring purchases. Notify the user about the error.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        let callback = self.restoreWaiting.value
        guard let done = callback else {
            return self.log.e("No restore callback, but restore operation failed".cause(error))
        }

        self.log.e("Restore operation failed".cause(error))
        self.restoreWaiting.value = nil
        done.fail(error)
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        BlockaLogger.e("StoreKit", "Removed transactions: \(transactions)")
    }

}
