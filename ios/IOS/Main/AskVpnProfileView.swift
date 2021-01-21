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

struct AskVpnProfileView: View {

    @ObservedObject var homeVM: HomeViewModel
    @Binding var activeSheet: ActiveSheet?

    private let network = NetworkService.shared

    var body: some View {
        NavigationView {
            VStack {
                BlokadaView(animate: true)
                    .frame(width: 100, height: 100)

                Text(L10n.mainAskForPermissionsHeader)
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Text(L10n.mainAskForPermissionsDescription)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.leading, .trailing], 40)
                    .padding([.top, .bottom])

                Button(action: {
                    Links.openInBrowser(Links.whyVpnPermissions())
                }) {
                    Text(L10n.universalActionLearnMore)
                        .padding()
                }

                VStack {
                    Button(action: {
                        self.activeSheet = nil
                        self.network.createVpnProfile { _, _ in
                            self.homeVM.switchMain(activate: true, noPermissions: {}, showRateScreen: {})
                        }
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
                    self.activeSheet = nil
                }) {
                    Text(L10n.universalActionCancel)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
    }
}

struct AskVpnProfileView_Previews: PreviewProvider {
    static var previews: some View {
        AskVpnProfileView(homeVM: HomeViewModel(), activeSheet: .constant(nil))
    }
}
