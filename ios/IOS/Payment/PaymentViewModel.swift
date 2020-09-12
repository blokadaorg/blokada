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

struct PaymentViewModel {

    let product: Product

    init(_ name: String) {
        self.product = Product(id: name, title: name,
                          description: "Mocked product description", price: "9.99", period: 6  )
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
