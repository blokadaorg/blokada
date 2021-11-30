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

struct LeaseView: View {

    let vm: LeaseViewModel

    var body: some View {
        HStack {
            Image(systemName: Image.fAccount)
                .imageScale(.large)
                .foregroundColor(Color.secondary)
                .frame(width: 48, height: 48)

            if vm.isMe {
                Text(vm.name).bold()
                    + Text(L10n.accountLeaseLabelThisDevice)
            } else {
                Text(vm.name)
            }
        }
    }
}

struct LeaseView_Previews: PreviewProvider {
    static var previews: some View {
        LeaseView(vm: LeaseViewModel(mocked: "Mocked"))
            .previewLayout(.sizeThatFits)
    }
}
