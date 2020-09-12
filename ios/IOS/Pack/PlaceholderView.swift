//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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
