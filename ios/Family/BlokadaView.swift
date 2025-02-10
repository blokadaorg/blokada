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

struct BlokadaView: View {

    @State var animate = false
    @State var point = UnitPoint(x: 1, y: 1)

    var body: some View {
        Rectangle()
            .fill(.white)
            .mask(
                Image(Image.iBlokada)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
    }
}

struct BlokadaView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BlokadaView(animate: true).previewLayout(.fixed(width: 128, height: 128))
            BlokadaView().previewLayout(.fixed(width: 128, height: 128))
            BlokadaView().previewLayout(.fixed(width: 64, height: 64))
        }
    }
}
