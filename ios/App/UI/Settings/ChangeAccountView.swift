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

struct ChangeAccountView: View {

    @ObservedObject var vm = ViewModels.account
    @ObservedObject var contentVM = ViewModels.content

    @State var accountId = ""

    var body: some View {
            Form {
                Section(header: Text(L10n.accountLogoutDescription)) {
                    HStack {
                        TextField(L10n.accountIdStatusUnchanged, text: $accountId)
                            .autocapitalization(.none)
                        Spacer()
                        Button(action: {
                            self.vm.restoreAccount(self.accountId) {
                                self.contentVM.dismissSheet()
                            }
                        }) {
                            Text(L10n.universalActionSave)
                        }
                        .disabled(self.accountId == "" || self.accountId == self.vm.id)
                    }
                }

                Section(header: Text(L10n.universalLabelHelp)) {
                     HStack {
                        Text(L10n.accountActionHowToRestore)
                        Spacer()

                        Button(action: {
                            self.contentVM.openLink(Link.HowToRestore)
                        }) {
                            Image(systemName: Image.fInfo)
                                .imageScale(.large)
                                .foregroundColor(Color.cAccent)
                                .frame(width: 32, height: 32)
                        }
                    }
                    Button(action: {
                        self.contentVM.openLink(Link.Support)
                    }) {
                        Text(L10n.universalActionContactUs)
                    }
                }
        }
            .navigationBarTitle(L10n.accountHeaderLogout)
        .accentColor(Color.cAccent)
        .alert(isPresented: self.$vm.showError) {
            Alert(title: Text(L10n.alertErrorHeader), message: Text(self.vm.error!),
                  dismissButton: Alert.Button.default(
                    Text(L10n.universalActionClose), action: { self.vm.error = nil }
                )
            )
        }
    }
}

struct ChangeAccountView_Previews: PreviewProvider {
    static var previews: some View {
        ChangeAccountView()
    }
}
