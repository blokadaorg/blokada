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

struct SettingsTabView: View {

    @ObservedObject var homeVM: HomeViewModel
    @ObservedObject var vm: AccountViewModel
    @ObservedObject var tabVM: TabViewModel
    @ObservedObject var inboxVM: InboxViewModel
    @ObservedObject var leaseVM: LeaseListViewModel

    @Binding var activeSheet: ActiveSheet?

    var body: some View {
        GeometryReader { geo in
             NavigationView {
               Form {
                HStack {
                    BlokadaView(animate: true)
                      .frame(width: 64, height: 64)
                      .padding()

                    if self.vm.active {
                        L10n.accountStatusText(self.vm.type, self.vm.activeUntil)
                            .toBlokadaText()
                            .font(.footnote)
                            .padding(.trailing)
                    } else {
                        L10n.accountStatusTextLibre
                            .toBlokadaText()
                            .font(.footnote)
                            .padding(.trailing)
                    }
                }

                Section(header: Text(L10n.accountSectionHeaderPrimary)) {
                    NavigationLink(destination: AccountView(vm: self.vm, activeSheet: self.$activeSheet), tag: "manage", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: Image.fAccount)
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.accountActionMyAccount)

                        }
                    }

                    NavigationLink(destination: InboxView(vm: self.inboxVM, tabVM: self.tabVM), tag: "inbox", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: "tray")
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.accountActionInbox)
                        }

                        Spacer()

                        if self.tabVM.hasInboxBadge() {
                            BadgeView(number: self.tabVM.inboxBadge)
                                .padding(.trailing, 8)
                        }
                    }

                    NavigationLink(destination: EncryptionView(homeVM: self.homeVM, activeSheet: self.$activeSheet), tag: "encryption", selection: self.$tabVM.selection) {
                         HStack {
                          Image(systemName: "lock")
                              .imageScale(.large)
                              .foregroundColor(.secondary)
                              .frame(width: 32, height: 32)

                            Text(L10n.accountActionEncryption)
                         }
                     }

                    NavigationLink(destination: LeaseListView(vm: self.leaseVM), tag: "leases", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: Image.fComputer)
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.accountActionDevices)

                        }
                    }
                }

                    Section(header: Text(L10n.accountSectionHeaderOther)) {
                        NavigationLink(destination: ChangeAccountView(vm: self.vm, activeSheet: self.$activeSheet), tag: "changeaccount", selection: self.$tabVM.selection) {
                            HStack {
                             Image(systemName: Image.fLogout)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.accountActionLogout)

                            }
                        }

                         Button(action: {
                            self.activeSheet = .help
                         }) {
                            HStack {
                             Image(systemName: Image.fHelp)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.universalActionSupport)
                                    .foregroundColor(Color.primary)

                            }
                        }

                        Button(action: {
                            Links.openInBrowser(Links.credits())
                        }) {
                            HStack {
                             Image(systemName: Image.fAbout)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.accountActionAbout)
                                    .foregroundColor(.primary)

                            }
                        }
                    }
               }
               .navigationBarTitle(L10n.accountSectionHeaderSettings)

                DoubleColumnPlaceholderView()
           }
            .accentColor(Color.cAccent)
            .padding(.leading, geo.size.height > geo.size.width ? 1 : 0) // To force double panel
        }
    }
}

struct SettingsTabView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsTabView(homeVM: HomeViewModel(), vm: AccountViewModel(), tabVM: TabViewModel(), inboxVM: InboxViewModel(), leaseVM: LeaseListViewModel(), activeSheet: .constant(nil))
    }
}
