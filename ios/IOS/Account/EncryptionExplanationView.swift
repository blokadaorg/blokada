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

struct EncryptionExplanationView: View {

    @Binding var activeSheet: ActiveSheet?

    @ObservedObject var vm: HomeViewModel

    @State var level: Int

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    HStack {
                        Spacer()
                        VStack {
                            LevelView(level: self.level, animate: true)
                                .frame(width: 100, height: 100)

                            Text(level >= 3 ? L10n.accountEncryptLevelHigh : level >= 2 ? L10n.accountEncryptLevelMedium : L10n.accountEncryptLevelLow)
                                .font(.largeTitle)
                                .bold()
                                .padding()


                            VStack(alignment: .leading) {
                                HStack(alignment: .top) {
                                    Image(systemName: "shield.lefthalf.fill")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.accountEncryptLabelDnsOnly)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.accountEncryptDescDnsOnly)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.bottom)
                                .saturation(level >= 2 ? 1 : 0)
                                .opacity(level >= 2 ? 1 : 0.3)

                                HStack(alignment: .top) {
                                    Image(systemName: Image.fShield)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 48, height: 48)
                                        .padding([.leading, .trailing], 8)
                                        .foregroundColor(Color.cAccent)

                                    VStack(alignment: .leading) {
                                        Text(L10n.accountEncryptLabelEverything)
                                            .font(.system(size: 20))
                                            .bold()
                                            .padding(.bottom)

                                        Text(L10n.accountEncryptDescEverything)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.bottom)
                                .saturation(level >= 3 ? 1 : 0)
                                .opacity(level >= 3 ? 1 : 0.3)
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

                    if level >= 3 {
                        Button(action: {
                            self.activeSheet = nil
                        }) {
                            ZStack {
                                ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)
                                Text(L10n.universalActionDone)
                                    .foregroundColor(.white)
                                    .bold()
                            }
                        }
                    } else if level >= 2 {
                        Button(action: {
                            self.activeSheet = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                                self.activeSheet = .plus
                            })
                        }) {
                            ZStack {
                                ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)
                                L10n.universalActionUpgrade
                                    .toBlokadaPlusText(color: .white, plusColor: .white)
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        Button(action: {
                            self.activeSheet = nil

                            DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                                // A copypaste from PowerView
                                self.vm.mainSwitch = true
                                self.vm.switchMain(activate: self.vm.mainSwitch,
                                    noPermissions: {
                                        // A callback trigerred when there is no VPN profile
                                        self.activeSheet = .askvpn
                                    },
                                    showRateScreen: {
                                        self.activeSheet = .rate
                                    }
                                )
                                })
                        }) {
                            ZStack {
                                ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)
                                L10n.accountEncryptActionTurnOn
                                    .toBlokadaText()
                                    .foregroundColor(.white)
                            }
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
                    self.activeSheet = nil
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

struct EncryptionExplanationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EncryptionExplanationView(activeSheet: .constant(nil), vm: HomeViewModel(), level: 1)
            EncryptionExplanationView(activeSheet: .constant(nil), vm: HomeViewModel(), level: 2)
        }
    }
}
