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

struct PackConfigView: View {

    let text: String

    var body: some View {
         Text(text)
           .bold()
           .font(.subheadline)
            .foregroundColor(.primary)
           .padding(.leading, 18)
           .padding(.trailing, 18)
           .padding(.top, 4)
           .padding(.bottom, 4)
           .background(
               RoundedRectangle(cornerRadius: 8)
                   .fill(Color(UIColor.systemGray5))
           )
    }
}

struct PackConfigView_Previews: PreviewProvider {
    static var previews: some View {
        PackConfigView(text: "Blue")
    }
}
