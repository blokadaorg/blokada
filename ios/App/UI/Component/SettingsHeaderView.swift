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

struct SettingsHeaderView: View {

    @ObservedObject var vm = ViewModels.account

    var body: some View {
        HStack {
            BlokadaView(animate: true)
            .frame(width: 64, height: 64)
            .padding([.bottom, .top, .trailing], 6)

            if self.vm.active && self.vm.type != .Libre {
                L10n.accountStatusText(
                    self.vm.type, self.vm.activeUntil
                )
                .toBlokadaText()
                .font(.footnote)
                .padding(.trailing)
            } else {
                L10n.accountStatusTextInactive
                .toBlokadaText()
                .font(.footnote)
                .padding(.trailing)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            }
        }
    }
}

struct SettingsHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsHeaderView()
    }
}
