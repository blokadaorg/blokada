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

struct PaymentGatewayView: View {

    @ObservedObject var vm: PaymentGatewayViewModel

    @Binding var activeSheet: ActiveSheet?

    @State var showPrivacySheet = false
    @State var showPlusFeaturesSheet = false

    var body: some View {
        if self.vm.accountActive {
            self.activeSheet = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                self.activeSheet = .activated
            })
        }

        return ZStack(alignment: .topTrailing) {
            ScrollView {
                HStack {
                    Spacer()
                    VStack {
                        HStack {
                            Spacer()

                            Text("BLOKADA")
                                .fontWeight(.heavy)
                                .kerning(3)
                                .foregroundColor(.primary)
                                .font(.title)
                                + Text("+")
                                    .foregroundColor(Color.cActivePlus)
                                    .bold()
                                    .font(.title)

                            Spacer()
                        }

                        L10n.paymentTitle.withBoldSections(font: .system(size: 13))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .font(.system(size: 13))
                            .padding(.top, 32)
                            .padding(.leading, 24)
                            .padding(.trailing, 32)

                        HStack(alignment: .top) {
                            Spacer()
                            VStack {
                                BenefitView(icon: Image.fLocation, text: L10n.paymentFeatureTitleChangeLocation)
                                //BenefitItemView(icon: Image.fComputer, text: "Up to 3 Devices")
                            }
                            VStack {
                                BenefitView(icon: Image.fShield, text: L10n.paymentFeatureTitleEncryptData)
                                //BenefitItemView(icon: Image.fHide, text: "No Ads")
                            }
                            VStack {
                                BenefitView(icon: Image.fSpeed, text: L10n.paymentFeatureTitleFasterConnection)
                                //BenefitItemView(icon: Image.fMessage, text: "Great Support")
                            }
                            Spacer()
                        }
                        .padding(.top, 18)
                        .padding(.bottom, 18)

                        Text(L10n.paymentActionSeeAllFeatures)
                            .foregroundColor(Color.cActivePlus)
                            .padding(.top, 12)
                            .onTapGesture {
                                withAnimation {
                                    self.showPlusFeaturesSheet = true
                                }
                            }
                            .sheet(isPresented: self.$showPlusFeaturesSheet) {
                                PlusFeaturesView(showSheet: self.$showPlusFeaturesSheet)

                            }
                            .padding(.bottom, 18)

                        PaymentListView(vm: vm)
                            .frame(minHeight: 256)

                        Spacer()

                        VStack {
                            Text(L10n.paymentActionRestore)
                                .foregroundColor(Color.cActivePlus)
                                .padding(.top, 8)
                                .multilineTextAlignment(.center)
                                .onTapGesture {
                                    withAnimation {
                                        self.vm.restoreTransactions()
                                    }
                                }

                            Text(L10n.paymentActionTermsAndPrivacy)
                                .foregroundColor(Color.cActivePlus)
                                .padding(.top, 12)
                                .multilineTextAlignment(.center)
                                .actionSheet(isPresented: self.$showPrivacySheet) {
                                    ActionSheet(title: Text(L10n.paymentActionTermsAndPrivacy), buttons: [
                                        .default(Text(L10n.paymentActionTerms)) {
                                            self.vm.showTerms()
                                        },
                                        .default(Text(L10n.paymentActionPolicy)) {
                                            self.vm.showPrivacy()
                                        },
                                        .default(Text(L10n.universalActionSupport)) {
                                            self.vm.showSupport()
                                        },
                                        .cancel()
                                    ])
                                }
                                .onTapGesture {
                                    withAnimation {
                                        self.showPrivacySheet = true
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: 500)
                    .padding()
                    .alert(isPresented: self.$vm.showError) {
                        Alert(title: Text(L10n.paymentAlertErrorHeader), message: Text(self.vm.error!),
                            dismissButton: Alert.Button.default(
                                Text(L10n.universalActionClose), action: { self.vm.cancel() }
                            )
                        )
                    }
                    .onAppear {
                        self.vm.fetchOptions()
                    }
                Spacer()
                }
            }

            Button(action: {
                withAnimation {
                    self.activeSheet = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                        self.activeSheet = .help
                    })
                }
            }) {
                Image(systemName: Image.fHelp)
                    .imageScale(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32, alignment: .center)
                    .padding(8)
            }
            .contentShape(Rectangle())
        }
    }
}

struct PaymentGatewayView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentGatewayView(vm: PaymentGatewayViewModel(), activeSheet: .constant(nil))
            PaymentGatewayView(vm: PaymentGatewayViewModel(), activeSheet: .constant(nil))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
            PaymentGatewayView(vm: PaymentGatewayViewModel(), activeSheet: .constant(nil))
                .previewDevice(PreviewDevice(rawValue: "iPhone X"))
        }
    }
}
