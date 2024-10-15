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

// Used in big screens mode, where we manage navigation ourselves.
struct SettingsFormNoNavView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var tabVM = ViewModels.tab
    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        Form {
            SettingsHeaderView()

            Section(header: Text(L10n.accountSectionHeaderPrimary)) {
                Button(action: {
                    self.tabVM.setSection("manage")
                }) {
                    SettingsItemView(
                        title: L10n.accountActionMyAccount,
                        image: Image.fAccount,
                        selected: self.tabVM.isSection("manage")
                    )
                }

                if (self.vm.type == .Plus) {
                    Button(action: {
                        self.tabVM.setSection("leases")
                    }) {
                        SettingsItemView(
                            title: L10n.webVpnDevicesHeader,
                            image: Image.fComputer,
                            selected: self.tabVM.isSection("leases")
                        )
                    }
                }

                if (self.vm.type != .Family) {
                    Button(action: {
                        self.tabVM.setSection("logRetention")
                    }) {
                        SettingsItemView(
                            title: L10n.activitySectionHeader,
                            image: Image.fChart,
                            selected: self.tabVM.isSection("logRetention")
                        )
                    }
                }
            }

            Section(header: Text(L10n.accountSectionHeaderOther)) {
                Button(action: {
                    self.tabVM.setSection("changeaccount")
                }) {
                    SettingsItemView(
                        title: L10n.accountActionLogoutNew,
                        image: Image.fLogout,
                        selected: self.tabVM.isSection("changeaccount")
                    )
                }

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
                    self.contentVM.openLink(LinkId.credits)
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

struct SettingsFormNoNavView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsFormNoNavView()
    }
}
