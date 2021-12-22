//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct NoLogRetentionView: View {

    @ObservedObject var vm = ViewModels.activity

    var body: some View {
        VStack() {
            Text(L10n.activityRetentionDesc)
                .foregroundColor(.secondary)
                .padding(32)

            VStack {
                Picker(L10n.activityRetentionHeader, selection: self.$vm.logRetentionSelected) {
                    Text(L10n.activityRetentionOptionNone)
                        .foregroundColor(Color.cAccent)
                        .tag("")
                    Text(L10n.activityRetentionOption24h)
                        .foregroundColor(Color.cAccent)
                        .tag("24h")
                }
                .pickerStyle(.wheel)

                Spacer()

                ZStack {
                    Button(action: {
                        Links.openInBrowser(Links.cloudPrivacy())
                    }) {
                        Text(L10n.activityRetentionPolicy)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding([.leading, .trailing], 40)
                    }
                }
                .frame(height: 48, alignment: .bottom)
                .padding(.bottom, 5)

                
                Button(action: {
                    self.vm.applyLogRetention()
                }) {
                    ZStack {
                        ButtonView(enabled: .constant(true), plus: .constant(true))
                            .frame(height: 44)
                        Text(L10n.universalActionContinue)
                            .foregroundColor(.white)
                            .bold()
                    }
                    .padding([.leading, .trailing, .bottom], 40)
                }
                .disabled(self.vm.logRetentionSelected == self.vm.logRetention)
                .opacity(self.vm.logRetentionSelected == self.vm.logRetention ? 0.5 : 1.0)
            }
        }
        .frame(maxWidth: 500)
    }

}

struct NoLogRetentionView_Previews: PreviewProvider {
    static var previews: some View {
        NoLogRetentionView()
    }
}
