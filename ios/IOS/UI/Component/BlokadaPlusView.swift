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

struct BlokadaPlusView: View {
    var body: some View {
        (
            Text("BLOKADA")
            + Text("+").foregroundColor(Color.cAccent)
        )
        .fontWeight(.heavy)
        .kerning(2)
        .bold()
        .padding()
    }
}

struct BlokadaPlusView_Previews: PreviewProvider {
    static var previews: some View {
        BlokadaPlusView()
    }
}
