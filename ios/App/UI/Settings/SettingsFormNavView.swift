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
                NavigationLink(
                    destination: AccountView(),
                    tag: "manage",
                    selection: self.$tabVM.navSetting
                ) {
                    SettingsItemView(
                        title: L10n.accountActionMyAccount,
                        image: Image.fAccount,
                        selected: false
                    )
                }

                if (self.vm.type == .Plus) {
                    NavigationLink(
                        destination: LeaseListView(),
                        tag: "leases",
                        selection: self.$tabVM.navSetting
                    ) {
                        SettingsItemView(
                            title: L10n.webVpnDevicesHeader,
                            image: Image.fComputer,
                            selected: false
                        )
                    }
                }

                NavigationLink(
                    destination: NoLogRetentionView(),
                    tag: "logRetention",
                    selection: self.$tabVM.navSetting
                ) {
                    SettingsItemView(
                        title: L10n.activitySectionHeader,
                        image: Image.fChart,
                        selected: false
                    )
                }
            }

            Section(header: Text(L10n.accountSectionHeaderOther)) {
                NavigationLink(
                    destination: ChangeAccountView(),
                    tag: "changeaccount",
                    selection: self.$tabVM.navSetting
                ) {
                    SettingsItemView(
                        title: L10n.accountActionLogout,
                        image: Image.fLogout,
                        selected: false
                    )
                }

                Button(action: {
                    self.contentVM.showSheet(.Help)
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
