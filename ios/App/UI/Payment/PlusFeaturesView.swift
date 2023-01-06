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

struct PlusFeaturesView: View {

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

                                Text("CLOUD")
                                    .fontWeight(.heavy).kerning(2).font(.system(size: 32))
                                    .foregroundColor(Color.cActive)
                                Spacer()
                            }
                            .padding(.bottom, 32)
                            
                            VStack(alignment: .leading) {
                                HStack(alignment: .top) {
                                    Image(systemName: Image.fHide)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleNoAds)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescNoAds)
                                            .lineLimit(5)
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
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleEncryptDns)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescEncryptDns)
                                            .lineLimit(5)
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
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitlePerformance)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescPerformance)
                                            .lineLimit(5)
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
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleBattery)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescBattery)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fComputer)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleDevicesCloud)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescDevicesCloud)
                                            .lineLimit(5)
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
                                        .foregroundColor(Color.cActive)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleSupport)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescSupport)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom)
                            }
                            .padding([.leading, .trailing])
        

                            HStack {
                                Spacer()
                                Text("BLOKADA")
                                    .fontWeight(.heavy).kerning(2).font(.system(size: 32))

                                Text("PLUS")
                                    .fontWeight(.heavy).kerning(2).font(.system(size: 32))
                                    .foregroundColor(Color.cActivePlus)
                                Spacer()
                            }
                            .padding(.top, 64)
                            .padding(.bottom, 32)

                            VStack(alignment: .leading) {
                                HStack(alignment: .top) {
                                    VStack {
                                        Image(systemName: Image.fHide)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)

                                        Image(systemName: Image.fShield)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)

                                        Image(systemName: Image.fSpeed)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)
                                    }

                                    VStack {
                                            Image(systemName: "battery.100")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)

                                        Image(systemName: Image.fComputer)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)

                                        Image(systemName: Image.fMessage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 32, height: 32)
                                            .foregroundColor(Color.cActive)
                                    }.padding([.trailing], 8)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleCloudVpn)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescCloudVpn)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10).fill(Color.cActive)
                                        RoundedRectangle(cornerRadius: 10).fill(Color.cSemiTransparent)
                                    }
                                )
                                .padding(.bottom, 32)

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fLocation)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleChangeLocation)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescChangeLocation)
                                            .lineLimit(5)
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
                                        Text(L10n.paymentFeatureTitleEncryptData)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescEncryptData)
                                            .lineLimit(5)
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
                                        Text(L10n.paymentFeatureTitleFasterConnection)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescFasterConnection)
                                            .lineLimit(5)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                }
                                .padding(.bottom, 32)

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fComputer)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.paymentFeatureTitleDevices)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.paymentFeatureDescDevices)
                                            .lineLimit(5)
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

struct PlusFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlusFeaturesView(showSheet: .constant(false))
            PlusFeaturesView(showSheet: .constant(false))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
            PlusFeaturesView(showSheet: .constant(false))
                .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (3rd generation)"))
        }
    }
}
