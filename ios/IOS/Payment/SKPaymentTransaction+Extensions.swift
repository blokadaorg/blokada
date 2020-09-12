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
