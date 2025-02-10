//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2024 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI
import StoreKit

extension View {
    func presentOfferCodeRedeemSheet() {
        if #available(iOS 16.0, *) {
            // iOS 16+ implementation using UIWindowScene
            guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                print("No active UIWindowScene found")
                return
            }

            Task {
                // Present the redeem sheet using the new iOS 16 API
                do {
                    try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                } catch {
                    print("Error presenting offer code redeem sheet: \(error)")
                }
            }
        } else {
            // Fallback on earlier versions
            DispatchQueue.main.async {
                SKPaymentQueue.default().presentCodeRedemptionSheet()
            }
        }
    }
}
