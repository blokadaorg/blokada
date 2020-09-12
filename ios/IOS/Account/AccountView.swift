//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct AccountView: View {

    @ObservedObject var vm: AccountViewModel

    @Binding var showSheet: Bool
    @Binding var sheet: String

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
                            self.sheet = "plus"
                            self.showSheet = true
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
        AccountView(vm: AccountViewModel(), showSheet: .constant(true), sheet: .constant(""))
    }
}
