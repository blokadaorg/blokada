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

struct PlaceholderView: View {

    @State var id: String = ""

    let desaturate: Bool

    var body: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    gradient: Gradient(colors: [Color(UIColor.systemGray5), Color(UIColor.systemGray3)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            Image("feature_\(id)")
                .resizable()
                .aspectRatio(contentMode: .fit)
                //.saturation(desaturate ? 0.5 : 1)
        }
    }
}

struct PlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlaceholderView(desaturate: true)
                .previewLayout(.fixed(width: 64, height: 64))
            PlaceholderView(desaturate: false)
                .previewLayout(.fixed(width: 64, height: 64))
                .environment(\.colorScheme, .dark)
            PlaceholderView(id: "stevenblack", desaturate: true)
                .previewLayout(.fixed(width: 64, height: 64))
        }
    }
}
