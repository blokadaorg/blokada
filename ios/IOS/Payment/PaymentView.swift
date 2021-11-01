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
                ButtonView(enabled: .constant(true), plus: .constant(self.vm.product.type == "plus"))

                if self.vm.product.trial {
                    Text("Start 7-Day Free Trial").foregroundColor(Color.primary).font(.headline)
                } else if self.vm.product.period == 12 {
                    Text("Subscribe Anually").foregroundColor(Color.primary).font(.headline)
                } else {
                    Text("Subscribe Monthly").foregroundColor(Color.primary).font(.headline)
                }
            }
            .frame(height: 44)

            Text(self.vm.description)
                .foregroundColor(Color.secondary)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 12)
        .padding(.leading, 8)
        .padding(.trailing, 8)
    }
}

struct PaymentView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentView(vm: PaymentViewModel("Product"))
    }
}
