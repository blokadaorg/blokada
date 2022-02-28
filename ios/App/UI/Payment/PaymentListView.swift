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

struct PaymentListView: View {

    @ObservedObject var vm: PaymentGatewayViewModel
    
    let showType: String

    @State var showLocationSheet = false

    var body: some View {
        VStack {
            ForEach(self.vm.options.filter({ it in it.product.type == self.showType}), id: \.self) { option in
                Button(action: {
                    withAnimation {
                        self.vm.buy(option.product)
                    }
                }) {
                    PaymentView(vm: option)
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct PaymentListView_Previews: PreviewProvider {
    static var previews: some View {
        let working = PaymentGatewayViewModel()
        working.working = true

        let error = PaymentGatewayViewModel()
        error.error = "Bad error"

        return Group {
            PaymentListView(vm: PaymentGatewayViewModel(), showType: "plus")
                .previewLayout(.sizeThatFits)

            PaymentListView(vm: error, showType: "plus")
                .previewLayout(.sizeThatFits)

            PaymentListView(vm: working, showType: "cloud")
                .previewLayout(.sizeThatFits)
        }
    }
}
