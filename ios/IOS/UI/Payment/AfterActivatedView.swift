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

    @Binding var activeSheet: ActiveSheet?
    @State var appear = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack {
                        BlokadaView(animate: true)
                            .frame(width: 100, height: 100)

                        Text(L10n.paymentHeaderActivated)
                            .font(.largeTitle)
                            .bold()
                            .padding()

                        Text(L10n.paymentActivatedDescription)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding([.leading, .trailing], 40)
                            .padding([.top, .bottom])

                        VStack {
                            Button(action: {
                                self.activeSheet = nil
                                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                                    self.activeSheet = .location
                                })
                            }) {
                                ZStack {
                                    ButtonView(enabled: .constant(true), plus: .constant(true))
                                        .frame(height: 44)
                                    Text(L10n.paymentActionChooseLocation)
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
                            self.activeSheet = nil
                        }) {
                            Text(L10n.universalActionDone)
                        }
                        .contentShape(Rectangle())
                    )
                }
            }
        }
        .opacity(self.appear ? 1 : 0)
        .animation(.easeInOut)
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
            AfterActivatedView(activeSheet: .constant(nil))
                .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            AfterActivatedView(activeSheet: .constant(nil))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
        }
    }
}
