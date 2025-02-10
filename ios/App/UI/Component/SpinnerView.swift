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

struct SpinnerView: View {

    @State var spin = false
    
    var foreverAnimation: Animation {
        Animation.linear(duration: 1.3)
            .repeatForever(autoreverses: false)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .trim(from: 0, to: 7/10)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 2)
                    .rotationEffect(.degrees(self.spin ? 0 : -360), anchor: .center)
                    .opacity(0.4)
                    .frame(width: 24, height: 24)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .onAppear {
                        withAnimation(foreverAnimation) {
                            self.spin = true
                        }
                    }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct SpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        SpinnerView()
    }
}
