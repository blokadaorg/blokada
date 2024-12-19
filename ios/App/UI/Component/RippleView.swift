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

    // Multiplier of gradient sizes for big screen
    let multiplier: CGFloat

    @ObservedObject var vm = ViewModels.home

    let ripples = 7

    @State var animate = false

    var foreverAnimation: Animation {
        Animation.linear(duration: 12)
            .repeatForever(autoreverses: true)
    }

    var body: some View {
        ZStack {
            // Gray gradient in the working or off state
            Rectangle()
            .fill(RadialGradient(gradient: Gradient(colors: [
                    Color.cBackground,
                    Color.cTertiaryBackground
                ]),
                center: .bottom,
                startRadius: (self.animate ? 300 * multiplier : 200 * multiplier),
                endRadius: (self.animate ? 800 * multiplier : 600 *  multiplier)
            ))
            .opacity(self.vm.working || self.vm.appState != .Activated ? 1.0 : 0.0)
            .animation(.spring(), value: self.vm.appState)

            // Blue gradient for Cloud state
            Rectangle()
            .fill(RadialGradient(gradient: Gradient(colors: [
                    Color.cBackground,
                    Color.cActive
                ]),
                center: .bottom,
                startRadius: (self.animate ? 500 * multiplier : 400 * multiplier),
                endRadius: (self.animate ? 1000 * multiplier : 900 * multiplier)
            ))
            .opacity(
                self.vm.working || self.vm.appState != .Activated || self.vm.vpnEnabled
                ? 0.0 : 1.0
            )
            .animation(.spring(), value: self.vm.working)

            // Orange gradient for Plus state
            Rectangle()
            .fill(RadialGradient(gradient: Gradient(colors: [
                    Color.cBackground,
                    Color.cActivePlus
                ]),
                center: .bottom,
                startRadius: (self.animate ? 500 * multiplier : 400 * multiplier),
                endRadius: (self.animate ? 1000 * multiplier : 900 * multiplier)
            ))
            .opacity(
                self.vm.working || self.vm.appState != .Activated || !self.vm.vpnEnabled
                ? 0.0 : 1.0
            )
            .animation(.spring(), value: self.vm.working)

//            if multiplier == 1.0 {
//                VStack {
//                    Rectangle().opacity(0.0)
//                    Rectangle().opacity(0.0)
//                    Rectangle().opacity(0.0)
//
//                    Rectangle()
//                    .fill(LinearGradient(
//                        gradient: Gradient(colors: [
//                            Color.cBackground,
//                            self.vm.appState != .Activated || self.vm.working ? Color.cTertiaryBackground :
//                                (self.vm.vpnEnabled ? Color.cActivePlus : Color.cActive)
//                        ]),
//                        startPoint: .center, endPoint: .bottom
//                    ))
//                    .opacity(self.vm.working ? 0.0 : 1.0)
//                    .animation(.spring(), value: self.vm.working)
//                }
//            }
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
        RippleView(multiplier: 1.0)
        RippleView(multiplier: 2.0)

    }
}
