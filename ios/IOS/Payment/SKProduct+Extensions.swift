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
            if (self.subscriptionPeriod?.numberOfUnits == 6) {
                return 12
            }
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
           return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))))"
       } else if self.productIdentifier == "cloud_12month" {
           let price = self.price.dividing(by: NSDecimalNumber(decimal: (length as NSNumber).decimalValue))
           //return "then \(L10n.paymentSubscriptionPerMonth(formatPrice(price: price)))"
           return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))))"
       } else {
           let price = self.price.dividing(by: NSDecimalNumber(decimal: (length as NSNumber).decimalValue))
           return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))). \(localInfo))"
       }
   }

    var isTrial: Bool {
        return self.introductoryPrice?.paymentMode == SKProductDiscount.PaymentMode.freeTrial
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
