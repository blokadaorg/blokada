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

struct AccountView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var contentVM = ViewModels.content

    @State var showChangeAccount = false
    @State var showDevices = false

    @State var id = "••••••"

    var body: some View {
        Form {
            Section(header: Text(L10n.accountSectionHeaderGeneral)) {
                Button(action: {
                    if self.id == "••••••" {
                        self.vm.authenticate { id in
                            self.id = id
                        }
                    }
                }) {
                    HStack {
                        Text(L10n.accountLabelId)
                        .foregroundColor(Color.cPrimary)
                        Spacer()
                        Text(self.id)
                            .foregroundColor(Color.secondary)
                    }
                }
                .contextMenu {
                    Button(action: {
                        self.vm.authenticate { id in
                            self.vm.copyAccountIdToClipboard()
                        }
                    }) {
                        Text(L10n.universalActionCopy)
                        Image(systemName: Image.fCopy)
                    }
                }
            }
            if self.vm.active {
                Section(header: Text(L10n.accountSectionHeaderSubscription)) {
                    HStack {
                        Text(L10n.accountLabelType)
                        Spacer()
                        Text(self.vm.type.toString()).foregroundColor(.secondary)
                    }

                    HStack {
                        Text(L10n.accountLabelActiveUntil)
                        Spacer()
                        Text(self.vm.activeUntil).foregroundColor(.secondary)
                    }

                    if self.vm.active {
                        Button(action: {
                            self.contentVM.openLink(Link.ManageSubscriptions)
                        }) {
                            Text(L10n.accountActionManageSubscription)
                        }
                    } else {
                        Button(action: {
                            self.contentVM.showSheet(.Payment)
                        }) {
                            L10n.universalActionUpgrade.toBlokadaPlusText()
                        }
                    }
                }
            }
            Section(header: Text(L10n.universalLabelHelp)) {
                HStack {
                    Text(L10n.accountActionWhyUpgrade)
                    Spacer()

                    Button(action: {
                        self.contentVM.openLink(Link.WhyVpn)
                    }) {
                        Image(systemName: Image.fInfo)
                            .imageScale(.large)
                            .foregroundColor(Color.cAccent)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .navigationBarTitle(L10n.accountActionMyAccount)
        .accentColor(Color.cAccent)
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView()
    }
}
