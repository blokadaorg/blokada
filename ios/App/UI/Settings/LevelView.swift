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
