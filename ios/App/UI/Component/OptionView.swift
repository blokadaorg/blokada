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

struct OptionView: View {

    let text: String
    let image: String
    let active: Bool

    var body: some View {
        VStack {
            HStack {
                Image(systemName: self.image)
                    .imageScale(.large)
                    .foregroundColor(self.active ? Color.cAccent : Color.secondary)
                    .frame(width: 32, height: 32)

                Text(self.text).fontWeight(self.active ? .bold : .regular)

                Spacer()

                if self.active {
                    Image(systemName: Image.fCheckmark)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color.cActivePlus)
                }
            }
            .padding([.leading, .trailing])
            .padding([.top, .bottom], 4)
        }
    }
}

struct OptionView_Previews: PreviewProvider {
    static var previews: some View {
        OptionView(text: "Option", image: Image.fHelp, active: false)
        OptionView(text: "Option2", image: Image.fAbout, active: true)
    }
}
