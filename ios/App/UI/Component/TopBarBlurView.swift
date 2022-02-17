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

struct TopBarBlurView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets

    var body: some View {
        // Blur bg below top bar
        VStack {
            if #available(iOS 15.0, *) {
                HStack {
                    EmptyView()
                    Spacer()
                }
                .frame(height: self.safeAreaInsets.top)
                .background(.ultraThinMaterial)
            } else {
                HStack {
                    EmptyView()
                    Spacer()
                }
                .frame(height: self.safeAreaInsets.top)
                .background(Color.cSecondaryBackground)
            }
            Spacer()
        }
    }

}

struct TopBarBlurView_Previews: PreviewProvider {
    static var previews: some View {
        TopBarBlurView()
    }
}
