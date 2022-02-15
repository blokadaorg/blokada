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

struct RippleView: View {

    @ObservedObject var vm = ViewModels.home
    @ObservedObject var tabVM = ViewModels.tab

    let ripples = 7

    @State var animate = false

    var foreverAnimation: Animation {
        Animation.linear(duration: 24)
            .repeatForever(autoreverses: true)
    }

    var body: some View {
        ZStack {
            ForEach(1 ..< self.ripples, id: \.self) { i in
                ZStack {
                    Circle()
//                    .fill(Color(
//                        red: 1 + 0.06 * (5.0 - CGFloat(i)),
//                        green: 0.58 + 0.06 * (5.0 - CGFloat(i)),
//                        blue: 0 + 0.06 * (5.0 - CGFloat(i))
//                    ))
//                    .fill(Color(
//                        red: 0.0431 + 0.06 * (5.0 - CGFloat(i)),
//                        green: 0.517 + 0.06 * (5.0 - CGFloat(i)),
//                        blue: 1 + 0.06 * (5.0 - CGFloat(i))
//                    ))
                    .fill(Color(
                        red: 0.0 + (0.2 - 0.05 * CGFloat(i)) + (self.animate ? 0.00431 : 0),
                        green: 0.0 + (0.2 - 0.05 * CGFloat(i)) + (self.animate ? 0.0517 : 0),
                        blue: 0.0 + (0.2 - 0.05 * CGFloat(i)) + (self.animate ? 0.1 : 0)
                    ))
                    .padding((self.animate ? 200 : 240) - 300 / CGFloat(i) * 1.9)
                    //.padding(.leading, (self.animate ? -50 : 50) - 300 / CGFloat(i))
                    //.padding(.trailing, (self.animate ? 20 : -40) - 600 / CGFloat(i))
                    //.padding(.bottom, (self.animate ? -10 : 30) - 600 / CGFloat(i) * 1.5)
                    //.padding(.bottom, (self.animate ? 80 : -40) - 600 / CGFloat(i) * 1.5)
                }
            }
        }
        .onAppear {
            withAnimation(foreverAnimation) {
                self.animate = true
            }
        }
    }
}

struct RippleView_Previews: PreviewProvider {
    static var previews: some View {
        RippleView()
    }
}
