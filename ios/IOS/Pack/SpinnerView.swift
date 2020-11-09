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

struct SpinnerView: View {

    @State var spin = false
    
    var foreverAnimation: Animation {
        Animation.linear(duration: 1.3)
            .repeatForever(autoreverses: false)
    }

    var body: some View {
        Circle()
            .trim(from: 0, to: 7/10)
            .stroke(Color(UIColor.systemGray4), lineWidth: 2)
            .rotationEffect(.degrees(self.spin ? 0 : -360), anchor: .center)
            .opacity(0.4)
            .frame(width: 24, height: 24)
            .onAppear {
                withAnimation(foreverAnimation) {
                    self.spin = true
                }
            }
    }
}

struct SpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        SpinnerView()
    }
}
