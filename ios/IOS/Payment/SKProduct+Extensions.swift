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

extension SKProduct {

    private func formatPrice(price: NSNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = self.priceLocale
        return formatter.string(from: price)!
    }

    var localPrice: String {
        formatPrice(price: self.price)
    }

    var durationMonths: Int {
        switch self.subscriptionPeriod?.unit {
        case .year:
            return (self.subscriptionPeriod?.numberOfUnits ?? 1) * 12
        default:
            return self.subscriptionPeriod?.numberOfUnits ?? 1
        }
    }

    var localTitle: String {
        let length = self.durationMonths
        if length == 1 {
            return L10n.paymentSubscription1Month
        } else {
            return L10n.paymentSubscriptionManyMonths(String(length))
        }
    }

    var localDescription: String {
       let length = self.durationMonths
       if length == 1 {
           return ""
       } else {
        let price = self.price.dividing(by: NSDecimalNumber(decimal: (length as NSNumber).decimalValue))
        return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))). \(localInfo))"
       }
   }

    private var localInfo: String {
        switch (self.durationMonths) {
        case 12:
            return L10n.paymentSubscriptionOffer("20%")
        case 6:
            return L10n.paymentSubscriptionOffer("10%")
        default:
            return ""
        }
    }

}
