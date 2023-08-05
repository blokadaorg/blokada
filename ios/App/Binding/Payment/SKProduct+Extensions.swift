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
       } else if self.productIdentifier == "cloud_12month" || self.productIdentifier == "family_12months" {
           let price = self.price.dividing(by: NSDecimalNumber(decimal: (length as NSNumber).decimalValue))
           //return "then \(L10n.paymentSubscriptionPerMonth(formatPrice(price: price)))"
           return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))))"
       } else {
           let price = self.price.dividing(by: NSDecimalNumber(decimal: (length as NSNumber).decimalValue))
           return "(\(L10n.paymentSubscriptionPerMonth(formatPrice(price: price))). \(localInfo))"
       }
   }

    var getTrialLength: Int? {
        if let introPrice = self.introductoryPrice, introPrice.paymentMode == SKProductDiscount.PaymentMode.freeTrial {
            let period = introPrice.subscriptionPeriod
            switch (period.unit) {
                case .day:
                    return period.numberOfUnits;
                default:
                    return 7 // TODO: just a fallback
            }
        }

        return nil
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
