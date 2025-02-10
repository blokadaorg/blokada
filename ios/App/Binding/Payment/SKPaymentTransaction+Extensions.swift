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

extension SKPaymentTransaction {
    func brief() -> String {
        var brief = "id=\(transactionIdentifier ?? "nil"), state=\(stateToString()), date=\(transactionDate?.description ?? "nil"), product=\(payment.productIdentifier)"

        if let error = error {
            brief += ", error=\(error)"
        }

        if let original = original {
            brief += ", original=(\(original.brief()))"
        }

        return "Transaction(\(brief))"
    }

    func stateToString() -> String {
        switch self.transactionState {
            case .purchasing: return "purchasing"
            case .deferred: return "purchasing"
            case .purchased: return "purchased"
            case .failed: return "failed"
            case .restored: return "restored"
            default: return "unknown"
        }
    }

    func date() -> Date {
        return transactionDate ?? Date(timeIntervalSince1970: 0)
    }
}
