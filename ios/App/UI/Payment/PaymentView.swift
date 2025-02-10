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

import SwiftUI

struct PaymentView: View {

    let vm: PaymentViewModel

    var body: some View {
        return VStack {
            ZStack {
                ButtonView(enabled: .constant(true), plus: .constant(self.vm.product.type == "plus" || self.vm.product.type == "family"))

                VStack {
                    if let trial = self.vm.product.trial {
                        Text(L10n.paymentPlanCtaTrialLength(trial))
                        .lineLimit(/*@START_MENU_TOKEN@*/2/*@END_MENU_TOKEN@*/)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .foregroundColor(getColor())
                        .font(.headline)
                        .padding(.bottom, 1)

                        Text(L10n.paymentSubscriptionPerYearThen(self.vm.price))
                        .foregroundColor(getColor())
                    } else if self.vm.product.periodMonths == 12 {
                        Text(L10n.paymentPlanCtaAnnual)
                        .foregroundColor(getColor())
                        .font(.headline)
                        .padding(.bottom, 1)

                        Text(L10n.paymentSubscriptionPerYear(self.vm.price))
                        .foregroundColor(getColor())
                    } else {
                    Text(L10n.paymentPlanCtaMonthly)
                        .foregroundColor(getColor())
                        .font(.headline)
                        .padding(.bottom, 1)

                        Text(L10n.paymentSubscriptionPerMonth(self.vm.price))
                        .foregroundColor(getColor())
                    }
                }
            }
            .frame(height: 80)

            if self.vm.product.periodMonths > 1 {
                Text(self.vm.description)
                .foregroundColor(Color.secondary)
                .font(.caption)
                .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 12)
        .padding(.leading, 8)
        .padding(.trailing, 8)
    }
    
    func getColor() -> Color {
        return self.vm.product.type == "family" ? Color.white : Color.primary
    }
}

struct PaymentView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentView(vm: PaymentViewModel("Product"))
    }
}
