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

struct AfterActivatedView: View {

    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var homeVM = ViewModels.home

    @State var appear = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack {
                        Text(L10n.activatedHeader)
                            .font(.largeTitle)
                            .bold()
                            .padding()

                        Text((
                            self.homeVM.dnsPermsGranted &&
                            self.homeVM.notificationPermsGranted &&
                            (self.homeVM.accountType == .Cloud || self.homeVM.vpnPermsGranted) ?
                                L10n.activatedDescAllOk : L10n.activatedDesc
                        )
                        )
                            .fixedSize(horizontal: false, vertical: true)
                            .padding([.leading, .trailing], 12)
                            .padding([.top, .bottom])
                        
                        VStack(spacing: 0) {
                            Button(action: {
                            }) {
                                HStack {
                                    Image(systemName: Image.fCheckmark)
                                        .imageScale(.large)
                                        .foregroundColor(Color.cOk)
                                        .frame(width: 32, height: 32)

                                    Text(L10n.activatedLabelAccount(self.homeVM.accountType))
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)

                                    Spacer()
                                }
                                .padding([.leading, .trailing], 18)
                                .padding([.top, .bottom], 4)
                            }

                            if self.homeVM.notificationPermsGranted {
                                Button(action: {
                                }) {
                                    HStack {
                                        Image(systemName: Image.fCheckmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cOk)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelNotifYes)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            } else {
                                Button(action: {
                                    self.homeVM.finishSetup()
                                }) {
                                    HStack {
                                        Image(systemName: Image.fXmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cError)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelNotifNo)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            }

                            if self.homeVM.dnsPermsGranted {
                                Button(action: {
                                }) {
                                    HStack {
                                        Image(systemName: Image.fCheckmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cOk)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelDnsYes)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            } else {
                                Button(action: {
                                    self.homeVM.finishSetup()
                                }) {
                                    HStack {
                                        Image(systemName: Image.fXmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cError)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelDnsNo)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            }

                            if self.homeVM.accountType != .Plus {
                                Button(action: {
                                }) {
                                    HStack {
                                        Image(systemName: Image.fXmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cSecondaryBackground)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelVpnCloud)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            } else if !self.homeVM.vpnPermsGranted {
                                Button(action: {
                                    self.homeVM.finishSetup()
                                }) {
                                    HStack {
                                        Image(systemName: Image.fXmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cError)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelVpnNo)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            } else {
                                Button(action: {
                                    
                                }) {
                                    HStack {
                                        Image(systemName: Image.fCheckmark)
                                            .imageScale(.large)
                                            .foregroundColor(Color.cOk)
                                            .frame(width: 32, height: 32)

                                        Text(L10n.activatedLabelVpnYes)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)

                                        Spacer()
                                    }
                                    .padding([.leading, .trailing], 18)
                                    .padding([.top, .bottom], 4)
                                }
                            }
                        }

                        VStack {
                            Button(action: {
                                self.homeVM.finishSetup()
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
                        .padding(40)
                    }
                    .frame(maxWidth: 500)
                    .navigationBarItems(trailing:
                        Button(action: {
                            self.contentVM.stage.dismiss()
                        }) {
                            Text(L10n.universalActionDone)
                        }
                        .contentShape(Rectangle())
                    )
                }
            }
        }
        .opacity(self.appear ? 1 : 0)
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            self.appear = true
        }
    }
}

struct AfterActivatedView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AfterActivatedView()
                .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            AfterActivatedView()
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
        }
    }
}
