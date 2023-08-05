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

struct PaymentViewModel {

    let product: Product

    init(_ name: String) {
        self.product = Product(
            id: name, title: name,
            description: "Mocked product description",
            price: "9.99", pricePerMonth: "",
            periodMonths: 6, type: name.contains("Cloud") ? "cloud" : "plus",
            trial: nil, owned: false
        )
    }

    init( _ product: Product) {
        self.product = product
    }

    var name: String {
        return product.title
    }

    var description: String {
        return product.description
    }

    var price: String {
        return product.price
    }

}

extension PaymentViewModel: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(product.id)
    }
}

extension PaymentViewModel: Equatable {
    static func == (lhs: PaymentViewModel, rhs: PaymentViewModel) -> Bool {
        lhs.product.id == rhs.product.id
   }
}
