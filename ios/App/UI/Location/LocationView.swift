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

struct LocationView: View {

    let vm: LocationViewModel

    var body: some View {
        VStack {
            HStack {
                Image(self.vm.getFlag())
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                Text(self.vm.name)
                    .fontWeight(self.vm.isActive ? .bold : .regular)
                    .foregroundColor(self.vm.isActive ? Color.cAccent : Color.primary)
                    .padding(.leading, 8)

                Spacer()

                if self.vm.isActive {
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

struct LocationView_Previews: PreviewProvider {
    static var previews: some View {
        let selected = LocationViewModel(mocked: "New York")
        return Group {
            LocationView(vm: LocationViewModel(mocked: "Schweden"))
                .previewLayout(.sizeThatFits)
            LocationView(vm: selected)
                .previewLayout(.sizeThatFits)
        }
    }
}
