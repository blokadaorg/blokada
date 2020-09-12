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

struct BlokadaView: View {

    @State var animate = false
    @State var point = UnitPoint(x: 1, y: 1)

    var body: some View {
        Rectangle()
            .fill(LinearGradient(gradient:
                Gradient(colors: [Color.cActivePlusGradient, Color.cActivePlus]),
                                 startPoint: .top, endPoint: point)
            )
            .mask(
                Image(Image.iBlokada)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            )
//            .onAppear {
//                if self.animate {
//                    withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
//                        self.point = UnitPoint(x: 0, y: 0)
//                    }
//                }
//            }
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
