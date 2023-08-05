//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct PaymentFeaturesView: View {

    @Binding var showSheet: Bool

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    HStack {
                        Spacer()
                        VStack {
                            HStack {
                                Spacer()
                                Text("BLOKADA")
                                    .fontWeight(.heavy).kerning(2).font(.system(size: 32))

                                Text("FAMILY")
                                    .fontWeight(.heavy).kerning(2).font(.system(size: 32))
                                    .foregroundColor(Color.cAccent)
                                Spacer()
                            }
                            .padding(.bottom, 32)
                            
                            VStack(alignment: .leading) {
                                HStack(alignment: .top) {
                                    Image(systemName: "ipad.and.iphone")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.familyPaymentFeaturesDevicesHeader)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.familyPaymentFeaturesDevicesBody)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fSpeed)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitlePerformance)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.familyPaymentFeaturesPerformanceBody)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)
                                
                                
                                HStack(alignment: .top) {
                                    Image(systemName: Image.fShield)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleEncryptDns)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.familyPaymentFeaturesDnsBody)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)

                                HStack(alignment: .top) {
                                    Image(systemName: "battery.100")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleBattery)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.familyPaymentFeaturesBatteryBody)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)

                               

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fHide)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleNoAds)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescNoAds)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)
                                
                                HStack(alignment: .top) {
                                    Image(systemName: Image.fMessage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleSupport)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescSupport)
                                            .lineLimit(7)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom)
                                
                                Text("").padding(.bottom, 90)

                            }
                            .padding([.leading, .trailing])
                        }
                        .frame(maxWidth: 500)
                        Spacer()
                    }
                }
                VStack {
                    Spacer()

                    Button(action: {
                        self.showSheet = false
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.universalActionContinue)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                }
                .frame(maxWidth: 500)
                .padding([.leading, .trailing], 40)
                .padding(.bottom, 40)
                .background(
                    VStack {
                        Spacer()
                        Rectangle()
                            .fill(
                                LinearGradient(gradient: Gradient(stops: [
                                    .init(color: Color.cPrimaryBackground.opacity(0), location: 0),
                                    .init(color: Color.cPrimaryBackground, location: 0.45)
                                ]), startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: 120)
                    }
                )
            }
            .edgesIgnoringSafeArea(.bottom) // Fixes the scroll content drawn underneath the home bar

            .navigationBarItems(trailing:
                Button(action: {
                    self.showSheet = false
                }) {
                    Text(L10n.universalActionDone)
                    .foregroundColor(Color.cAccent)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .foregroundColor(Color.cPrimary)
        .multilineTextAlignment(.leading)
    }
}

struct PaymentFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentFeaturesView(showSheet: .constant(false))
            PaymentFeaturesView(showSheet: .constant(false))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
            PaymentFeaturesView(showSheet: .constant(false))
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (3rd generation)"))
        }
    }
}
