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

// Used in iPhone mode, where we utilize the built in navigation.
struct SettingsFormNavView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var tabVM = ViewModels.tab
    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        Form {
            SettingsHeaderView()
            
            Section(header: Text(L10n.accountSectionHeaderPrimary)) {
                SettingsItemView(
                    title: L10n.accountActionMyAccount,
                    image: Image.fAccount,
                    selected: false
                )
                .background(NavigationLink("", value: "manage").opacity(0))

                if (self.vm.type == .Plus) {
                    SettingsItemView(
                        title: L10n.webVpnDevicesHeader,
                        image: Image.fComputer,
                        selected: false
                    )
                    .background(NavigationLink("", value: "leases").opacity(0))
                }

                SettingsItemView(
                    title: L10n.activitySectionHeader,
                    image: Image.fChart,
                    selected: false
                )
                .background(NavigationLink("", value: "logRetention").opacity(0))
            }
            
            Section(header: Text(L10n.accountSectionHeaderOther)) {
                SettingsItemView(
                    title: L10n.accountActionLogout,
                    image: Image.fLogout,
                    selected: false
                )
                .background(NavigationLink("", value: "changeaccount").opacity(0))

                Button(action: {
                    self.contentVM.stage.showModal(.help)
                }) {
                    SettingsItemView(
                        title: L10n.universalActionSupport,
                        image: Image.fHelp,
                        selected: false
                    )
                }

                Button(action: {
                    self.contentVM.openLink(Link.Credits)
                }) {
                    SettingsItemView(
                        title: L10n.accountActionAbout,
                        image: Image.fAbout,
                        selected: false
                    )
                }
            }
        }
        .navigationBarTitle(L10n.mainTabSettings)
        .accentColor(Color.cAccent)
    }
}

struct SettingsFormNavView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsFormNavView()
    }
}
