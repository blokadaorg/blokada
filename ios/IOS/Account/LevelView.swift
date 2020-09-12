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

struct LevelView: View {

    @State var level = 1
    @State var animate = false
    @State var point = UnitPoint(x: 1, y: 1)

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color(UIColor.systemGray5))
                .mask(
                    Image(systemName: "chart.bar.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                )

            Rectangle()
            .fill(LinearGradient(gradient:
                Gradient(colors: [Color.cActivePlusGradient, Color.cActivePlus]),
                                 startPoint: .top, endPoint: point)
            )
            .mask(
                Image(systemName: "chart.bar.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .mask(
                       HStack {
                            Rectangle()
                            Rectangle().opacity(level >= 2 ? 1 : 0)
                            Rectangle().opacity(level >= 3 ? 1 : 0)
                        }
                    )
            )
        }
//        .onAppear {
//            if self.animate {
//                withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
//                    self.point = UnitPoint(x: 0, y: 0)
//                }
//            }
//        }
    }
}

struct LevelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LevelView(animate: true)
                .previewLayout(.fixed(width: 256, height: 256))
            LevelView(level: 2, animate: true)
                .previewLayout(.fixed(width: 256, height: 256))
                .environment(\.colorScheme, .dark)
                .background(Color.black)
            LevelView(level: 3)
                .previewLayout(.fixed(width: 256, height: 256))
            LevelView()
                .previewLayout(.fixed(width: 128, height: 128))
        }
    }
}
