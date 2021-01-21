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

    @ObservedObject var vm: AccountViewModel

    @Binding var activeSheet: ActiveSheet?

    @State var showChangeAccount = false
    @State var showDevices = false

    @State var id = "••••••"

    var body: some View {
            Form {
                Section(header: Text(L10n.accountSectionHeaderGeneral)) {
                    HStack {
                        Text(L10n.accountLabelId)
                        Spacer()
                        Text(self.id)
                            .foregroundColor(Color.secondary)   
                    }
                    .onTapGesture {
                        if self.id == "••••••" {
                            self.vm.authenticate { id in
                                self.id = id
                            }
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
                Section(header: Text(L10n.accountSectionHeaderSubscription)) {
                    HStack {
                        Text(L10n.accountLabelType)
                        Spacer()
                        Text(self.vm.type).foregroundColor(.secondary)
                    }

                    HStack {
                        Text(L10n.accountLabelActiveUntil)
                        Spacer()
                        Text(self.vm.activeUntil).foregroundColor(.secondary)
                    }

                    if self.vm.active {
                        Button(action: {
                            self.vm.openManageSubscriptions()
                        }) {
                            Text(L10n.accountActionManageSubscription)
                        }
                    } else {
                        Button(action: {
                            self.activeSheet = .plus
                        }) {
                            L10n.universalActionUpgrade.toBlokadaPlusText()
                        }
                    }
                }
                Section(header: Text(L10n.universalLabelHelp)) {
                    HStack {
                        Text(L10n.accountActionWhyUpgrade)
                        Spacer()

                        Button(action: {
                            Links.openInBrowser(Links.whyVpn())
                        }) {
                            Image(systemName: Image.fInfo)
                                .imageScale(.large)
                                .foregroundColor(Color.cAccent)
                                .frame(width: 32, height: 32)
                        }
                    }
                }
        }
        .navigationBarTitle(L10n.accountSectionHeaderMySubscription)
        .accentColor(Color.cAccent)
    }
}

struct AccountView_Previews: PreviewProvider {
    static var previews: some View {
        AccountView(vm: AccountViewModel(), activeSheet: .constant(nil))
    }
}
