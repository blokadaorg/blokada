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

struct TagView: View {

    let text: String
    let active: Bool

    var body: some View {
        HStack {
            Text(text.trTag())
            .lineLimit(1)
            .font(.footnote)
            .foregroundColor(.primary)
        }
        .frame(width: 74)
        .padding([.leading, .trailing], 14)
        .padding([.top, .bottom], 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
            .fill(self.active ? Color.cAccent : Color(UIColor.systemGray5))
        )
        .padding(.bottom, 8)
    }
}

struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TagView(text: "ads", active: false)
                .previewLayout(.sizeThatFits)
            TagView(text: "trackers", active: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
