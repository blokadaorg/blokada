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
                            SpinnerView()
                                .frame(width: 24, height: 24)
                                .padding(.bottom)

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
