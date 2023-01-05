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

class StoreKitService {

    fileprivate let fetchSKProductsT = SimpleTasker<[SKProduct]>("fetchSKProducts")

    private var cancellables = Set<AnyCancellable>()
    private let recentProducts = Atomic<[SKProduct]?>(nil)

    private let productIdentifiers = [
        "plus_month",
        "cloud_12month",
        "plus_12month",
    ]

    init() {
        onFetchSKProducts()
    }

    func fetchSKProducts() -> AnyPublisher<[SKProduct], Error> {
        if !SKPaymentQueue.canMakePayments() {
            return Fail<[SKProduct], Error>(error: CommonError.paymentNotAvailable)
            .eraseToAnyPublisher()
        }
        return fetchSKProductsT.send()
    }

    func onFetchSKProducts() {
        fetchSKProductsT.setTask { _ in Just(true)
            .flatMap { _ in
                Future<[SKProduct], Error> { promise in
                    let r = SKProductsRequest(productIdentifiers: Set(self.productIdentifiers))
                    let handler = StoreKitProductRequestHandler(promise)
                    r.delegate = handler
                    r.start()
                }
            }
            .eraseToAnyPublisher()
        }
    }

}

class StoreKitProductRequestHandler: NSObject, SKProductsRequestDelegate {

    private let promise: Future<[SKProduct], Error>.Promise

    init(_ promise: @escaping Future<[SKProduct], Error>.Promise) {
        self.promise = promise
    }

    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.products.isEmpty {
            promise(.failure(CommonError.paymentNotAvailable)) // TODO: better error?
        } else {
            promise(.success(
                // TODO: not sure if sorting here is necessary or nice
                response.products.sorted { a, b in a.durationMonths < b.durationMonths }
            ))
        }
    }

}
