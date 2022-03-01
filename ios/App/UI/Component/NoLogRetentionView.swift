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
    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        Form {
            Section(header: Text(L10n.activitySectionHeader)) {
                Text(L10n.activityRetentionDesc)
                .foregroundColor(.secondary)
                .padding()

                HStack {
                    Spacer()

                    VStack {
                        if self.vm.logRetention == "" {
                            OptionView(
                                text: L10n.activityRetentionOptionNone,
                                image: Image.fHide,
                                active: false
                            )

                            Button(action: {
                                self.vm.logRetentionSelected = "24h"
                                self.vm.applyLogRetention()
                            }) {
                                ZStack {
                                    ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)

                                    Text(L10n.homePowerActionTurnOn)
                                    .foregroundColor(.white)
                                    .bold()
                                }
                            }
                            .padding()
                            .frame(maxWidth: 300)
                        } else {
                            HStack {
                                Text(L10n.activityRetentionHeader)
                                .fixedSize(horizontal: false, vertical: true)
                                .multilineTextAlignment(.leading)
                                .padding()

                                Spacer()
                            }

                            OptionView(
                                text: L10n.activityRetentionOption24h,
                                image: Image.fShow,
                                active: false
                            )

                            Button(action: {
                                self.vm.logRetentionSelected = ""
                                self.vm.applyLogRetention()
                            }) {
                                ZStack {
                                    ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)

                                    Text(L10n.homePowerActionTurnOff)
                                    .foregroundColor(.white)
                                    .bold()
                                }
                            }
                            .padding()
                            .frame(maxWidth: 300)
                        }
                    }
                }

                Button(action: {
                    self.contentVM.openLink(Link.CloudPrivacy)
                }) {
                    Text(L10n.activityRetentionPolicy)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                .padding()
            }
        }
        .navigationBarTitle(L10n.activitySectionHeader)
        .accentColor(Color.cAccent)
    }
}

struct NoLogRetentionView_Previews: PreviewProvider {
    static var previews: some View {
        NoLogRetentionView()
    }
}
