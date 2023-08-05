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
    @ObservedObject var vm = ViewModels.journal
    @ObservedObject var contentVM = ViewModels.content

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                VStack(spacing: 0) {
                    HStack {
                        Text(L10n.activityRetentionDesc)
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                
                Text(L10n.activityActionsHeader)
                    .font(.system(size: 24))
                    .padding(.top)
                    .bold()
                
                VStack(spacing: 0) {
                    HStack {
                        Text(self.vm.logRetention == "" ? L10n.activityRetentionOptionNone : L10n.activityRetentionOption24h)
                        Spacer()
                        LoadingButtonView(action: {
                            if self.vm.logRetention == "" {
                                self.vm.logRetentionSelected = "24h"
                                self.vm.applyLogRetention()
                            } else {
                                self.vm.logRetentionSelected = ""
                                self.vm.applyLogRetention()
                            }
                        }, isOn: self.vm.logRetention != "", alignTrailing: true, loading: false)
                    }
                    .padding(12)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                Button(action: {
                    self.contentVM.openLink(LinkId.privacyCloud)
                }) {
                    Text(L10n.activityRetentionPolicy)
                        .multilineTextAlignment(.leading)
                        .font(.footnote)
                        .lineLimit(3)
                }
                .padding()
            }
            .padding()
            .padding(.bottom, 56)
        }
        .background(colorScheme == .dark ? Color.cBackground : Color.cSecondaryBackground)
        .navigationBarTitle(L10n.activitySectionHeader)
        .accentColor(Color.cAccent)
    }
}

struct NoLogRetentionView_Previews: PreviewProvider {
    static var previews: some View {
        NoLogRetentionView()
    }
}
