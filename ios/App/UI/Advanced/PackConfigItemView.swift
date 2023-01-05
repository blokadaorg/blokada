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

struct PackConfigItemView: View {

    let text: String
    let active: Bool

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "cube.box.fill")
                    .imageScale(.large)
                    .foregroundColor(self.active ? Color.cAccent : Color.cSecondaryBackground)
                    .frame(width: 32, height: 32)

                Text(self.text)
                .fontWeight(self.active ? .bold : .regular)
                .foregroundColor(Color.cPrimary)

                Spacer()

                if self.active {
                    Image(systemName: Image.fCheckmark)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color.cActivePlus)
                }
            }
        }
        .padding([.leading, .trailing])
        .padding([.top, .bottom], 4)
    }
}

struct PackConfigItemView_Previews: PreviewProvider {
    static var previews: some View {
        PackConfigItemView(text: "Blue", active: true)
    }
}
