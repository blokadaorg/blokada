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

    @State var showLocationSheet = false

    var body: some View {
        ZStack {
            VStack {
                VStack {
                    ForEach(self.vm.options, id: \.self) { option in
                        PaymentView(vm: option).onTapGesture {
                            withAnimation {
                                self.vm.buy(option.product)
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
                Spacer()
            }
            .padding(.top, 1)
            .opacity(self.vm.working || self.vm.options.isEmpty ? 0.0 : 1.0)
            .transition(.opacity)
            .animation(
                Animation.easeIn(duration: 0.3).repeatCount(1)
            )

            VStack {
                HStack {
                    Spacer()
                    VStack {
                        if self.vm.working {
                            if #available(iOS 14.0, *) {
                                ProgressView()
                                    .padding(.bottom)
                            } else {
                                SpinnerView()
                                    .frame(width: 24, height: 24)
                                    .padding(.bottom)
                            }

                            Text(L10n.universalStatusProcessing)
                                .multilineTextAlignment(.center)
                        } else if self.vm.accountActive {
                            Text(L10n.errorPaymentCanceled)
                                .multilineTextAlignment(.center)
                        } else {
                            Text(errorDescriptions[CommonError.paymentFailed]!)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(32)
                    Spacer()
                }
                Spacer()
            }
            .background(Color.cPrimaryBackground)
            .opacity(self.vm.working || self.vm.error != nil || self.vm.options.isEmpty || self.vm.accountActive ? 1.0 : 0.0)
        }
    }
}

struct PaymentListView_Previews: PreviewProvider {
    static var previews: some View {
        let working = PaymentGatewayViewModel()
        working.working = true

        let error = PaymentGatewayViewModel()
        error.error = "Bad error"

        return Group {
            PaymentListView(vm: PaymentGatewayViewModel())
                .previewLayout(.sizeThatFits)

            PaymentListView(vm: error)
                .previewLayout(.sizeThatFits)

            PaymentListView(vm: working)
                .previewLayout(.sizeThatFits)
        }
    }
}
