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

struct SettingsTabView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var tabVM = ViewModels.tab
    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        GeometryReader { geo in
             NavigationView {
               Form {
                HStack {
                    BlokadaView(animate: true)
                        .frame(width: 64, height: 64)
                        .padding([.bottom, .top, .trailing], 6)

                    if self.vm.active {
                        L10n.accountStatusText(self.vm.type, self.vm.activeUntil)
                            .toBlokadaText()
                            .font(.footnote)
                            .padding(.trailing)
                    } else {
                        "Your BLOKADA account is inactive."
                            .toBlokadaText()
                            .font(.footnote)
                            .padding(.trailing)
                    }
                }

                Section(header: Text(L10n.accountSectionHeaderPrimary)) {
                    NavigationLink(destination: AccountView(), tag: "manage", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: Image.fAccount)
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.accountActionMyAccount)
                                .padding(.leading, 6)

                        }
                    }

                    NavigationLink(destination: InboxView(), tag: "inbox", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: "tray")
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.accountActionInbox)
                                .padding(.leading, 6)
                                .lineLimit(1)
                        }

                        Spacer()

                       if self.tabVM.hasInboxBadge() {
                            BadgeView(number: self.tabVM.inboxBadge)
                                .padding(.trailing, 8)
                       }
                    }

                    if (self.vm.active && self.vm.type == .Plus ) {
                        NavigationLink(destination: LeaseListView(), tag: "leases", selection: self.$tabVM.selection) {
                            HStack {
                             Image(systemName: Image.fComputer)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.webVpnDevicesHeader)
                                    .padding(.leading, 6)

                            }
                        }
                    }

                    NavigationLink(destination: NoLogRetentionView(), tag: "logRetention", selection: self.$tabVM.selection) {
                        HStack {
                         Image(systemName: "chart.bar")
                             .imageScale(.large)
                             .foregroundColor(.secondary)
                             .frame(width: 32, height: 32)

                            Text(L10n.activitySectionHeader)
                                .padding(.leading, 6)

                        }
                    }
                }

                    Section(header: Text(L10n.accountSectionHeaderOther)) {
                        NavigationLink(destination: ChangeAccountView(), tag: "changeaccount", selection: self.$tabVM.selection) {
                            HStack {
                             Image(systemName: Image.fLogout)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.accountActionLogout)
                                    .padding(.leading, 6)

                            }
                        }

                         Button(action: {
                             self.contentVM.showSheet(.Help)
                         }) {
                            HStack {
                             Image(systemName: Image.fHelp)
                                 .imageScale(.large)
                                 .foregroundColor(.secondary)
                                 .frame(width: 32, height: 32)

                                Text(L10n.universalActionSupport)
                                    .foregroundColor(Color.primary)
                                    .padding(.leading, 6)

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
                                    .padding(.leading, 6)

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
        SettingsTabView()
    }
}
