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

struct ChangeAccountView: View {

    @ObservedObject var vm: AccountViewModel

    @Binding var showSheet: Bool
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
                                self.showSheet = false
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
                            Links.openInBrowser(Links.howToRestore())
                        }) {
                            Image(systemName: Image.fInfo)
                                .imageScale(.large)
                                .foregroundColor(Color.cAccent)
                                .frame(width: 32, height: 32)
                        }
                    }
                    Button(action: {
                        Links.openInBrowser(Links.support())
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
        ChangeAccountView(vm: AccountViewModel(), showSheet: .constant(true))
    }
}
