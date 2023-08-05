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
import Factory

// Used in iPhone mode, where we utilize the built in navigation.
struct SettingsFormNavView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var tabVM = ViewModels.tab
    @ObservedObject var contentVM = ViewModels.content

    @Injected(\.commands) private var commands
    @State private var showNewPin = false
    @State private var newPin = ""

    var body: some View {
        VStack {
            Form {
                SettingsHeaderView()
                    .cornerRadius(8)
                    .padding(.vertical, 12)
                
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
                    
                    if (self.vm.type != .Family) {
                        SettingsItemView(
                            title: L10n.activitySectionHeader,
                            image: Image.fChart,
                            selected: false
                        )
                        .background(NavigationLink("", value: "logRetention").opacity(0))
                    }
                    
                    if (self.vm.type == .Family) {
                        Button(action: {
                            self.showNewPin = true
                            self.newPin = ""
                        }) {
                            SettingsItemView(
                                title: L10n.lockChangePin,
                                image: "lock.fill",
                                selected: false
                            )
                        }
                        .alert(L10n.lockChangePin, isPresented: self.$showNewPin) {
                            TextField("", text: $newPin)
                                .keyboardType(.decimalPad)
                            Button(L10n.universalActionCancel, action: { self.showNewPin = false })
                            Button(L10n.universalActionSave, action: submit)
                        }
                    }
                }
                
                Section(header: Text(L10n.accountSectionHeaderOther)) {
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
        }
        .navigationBarTitle(L10n.mainTabSettings)
        .accentColor(Color.cAccent)
    }

    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .ordinal
        return formatter
    }()

    func submit() {
        self.showNewPin = false
        self.commands.execute(.setPin, self.newPin)
    }
}

struct SettingsFormNavView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsFormNavView()
    }
}
