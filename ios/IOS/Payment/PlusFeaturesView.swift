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

struct PlusFeaturesView: View {

    @Binding var showSheet: Bool

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    HStack {
                        Spacer()
                        VStack {
                            BlokadaView(animate: true)
                                .frame(width: 100, height: 100)

                            BlokadaPlusView()
                                .font(.largeTitle)


                            VStack(alignment: .leading) {
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
                                    }
                                }
                                .padding(.bottom)

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
                                    }
                                }
                                .padding(.bottom)

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
                                    }
                                }
                                .padding(.bottom)

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
                                    }
                                }
                                .padding(.bottom)

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
                                    }
                                }
                                .padding(.bottom)

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
                                    }
                                }
                                .padding(.bottom)
                            }
                            .padding([.leading, .trailing])

                            Text("")
                                .frame(height: 90)
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
                .padding(.bottom)
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

            .navigationBarItems(trailing:
                Button(action: {
                    self.showSheet = false
                }) {
                    Text(L10n.universalActionDone)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {

        }
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
