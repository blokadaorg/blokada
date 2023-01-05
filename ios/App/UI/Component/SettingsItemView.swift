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

struct SettingsItemView: View {

    var title: String
    var image: String
    var selected: Bool

    var body: some View {
        HStack {
            Image(systemName: image)
            .imageScale(.large)
            .foregroundColor(selected ? .cAccent : .secondary)
            .frame(width: 32, height: 32)

            Text(title)
            .foregroundColor(selected ? .cAccent : .primary)
            .padding(.leading, 6)
        }
    }
}

struct SettingsItemView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsItemView(
            title: L10n.accountActionMyAccount,
            image: Image.fAccount,
            selected: true
        )

        SettingsItemView(
            title: "Test",
            image: Image.fAbout,
            selected: false
        )
    }
}
