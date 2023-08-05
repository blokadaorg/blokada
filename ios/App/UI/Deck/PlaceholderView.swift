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
import CryptoKit

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

            Rectangle()
                .fill(Color(uiColor: generateColor(from: id)))
                .opacity(0.5)

//            Image("feature_\(id)")
//                .resizable()
//                .aspectRatio(contentMode: .fit)
//                //.saturation(desaturate ? 0.5 : 1)
        }
    }

    func generateColor(from string: String) -> UIColor {
        let hash = SHA256.hash(data: Data(string.utf8))
        let bytes = Array(hash)
        
        let red = CGFloat(bytes[0]) / 255.0
        let green = CGFloat(bytes[1]) / 255.0
        let blue = CGFloat(bytes[2]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
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
