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

struct SplashView: View {
    var body: some View {
        ZStack {
            Spacer()
            BlokadaView(animate: true)
                .frame(width: 120, height: 120)
            Spacer()
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .background(Color.cBackgroundSplash)
        .edgesIgnoringSafeArea(.all)
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SplashView()
            SplashView().environment(\.colorScheme, .dark)
            SplashView().previewDevice(PreviewDevice(rawValue: "iPhone X")).environment(\.colorScheme, .dark)
        }
    }
}
