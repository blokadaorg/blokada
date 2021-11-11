//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct DnsProfileConfiguredView: View {

    @Binding var activeSheet: ActiveSheet?

    private let networkDns = NetworkDnsService.shared

    var body: some View {
        NavigationView {
            VStack {
                Text("Enable in Settings")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Text("In the Settings app, navigate to General → VPN, DNS & Device Management → DNS and select Blokada.")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.leading, .trailing], 40)
                    .padding([.top, .bottom])

                VStack {
                    Button(action: {
                        self.activeSheet = nil
                       // DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                            self.networkDns.openSettingsScreen()
                       // })
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text("Open Settings")
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

struct DnsProfileConfiguredView_Previews: PreviewProvider {
    static var previews: some View {
        DnsProfileConfiguredView(activeSheet: .constant(nil))
    }
}
