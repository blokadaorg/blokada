//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI

struct ChangeAccountView2: View {
    @ObservedObject var vm = ViewModels.account
    @ObservedObject var contentVM = ViewModels.content

    @Environment(\.colorScheme) var colorScheme
    
    @State var accountId = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Image(systemName: Image.fInfo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                    .foregroundColor(Color.secondary)
                    .padding(.trailing)
                    
                    Text(L10n.accountLogoutDescription)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                
                Text(L10n.accountLabelId)
                    .font(.system(size: 24))
                    .padding(.top)
                    .bold()
                
                VStack(spacing: 0) {
                    HStack {
                        TextField(L10n.accountIdStatusUnchanged, text: $accountId)
                            .autocapitalization(.none)
                        Spacer()
                        Button(action: {
                            self.vm.restoreAccount(self.accountId) {
                                //self.contentVM.stage.dismiss()
                            }
                        }) {
                            Text(L10n.universalActionSave)
                        }
                        .disabled(self.accountId == ""/** || self.accountId == self.vm.id**/)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                Button(action: {
                    self.contentVM.openLink(LinkId.howToRestore)
                }) {
                    Text(L10n.accountActionHowToRestore)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .lineLimit(3)
                }
                .padding(.top)
                .padding()
                
                Button(action: {
                    self.contentVM.openLink(LinkId.support)
                }) {
                    Text(L10n.universalActionContactUs)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .lineLimit(3)
                }
                .padding([.leading, .trailing])
            }
            .padding()
            .padding(.bottom, 56)
        }
        .background(colorScheme == .dark ? Color.cBackground : Color.cSecondaryBackground)
        .navigationBarTitle(L10n.accountHeaderLogout)
        .accentColor(Color.cAccent)
    }
}

struct ChangeAccountView2_Previews: PreviewProvider {
    static var previews: some View {
        ChangeAccountView2()
    }
}
