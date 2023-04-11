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

struct CustomItemV: View {
    
    let item: String
    let allowed: Bool

    var body: some View {
        HStack {
            Rectangle()
            .fill(!allowed ? Color.red : Color.green)
            .frame(width: 3)
            .padding(.leading, 12)

            VStack(alignment: .leading) {
                Text(item)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    //.foregroundColor(self.vm.selected ? Color.cAccent : Color.primary)
                Text(allowed ? L10n.userdeniedTabAllowed : L10n.userdeniedTabBlocked)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
            }
            Spacer()
        }
        .frame(height: 54)
        .padding([.bottom, .top], 10)
        .padding([.trailing], 16)
    }
}

struct CustomItemV_Previews: PreviewProvider {
    static var previews: some View {
        CustomItemV(item: "example.com", allowed: true)
        CustomItemV(item: "example2.com", allowed: false)
    }
}
