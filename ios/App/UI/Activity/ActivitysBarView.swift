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

struct ActivitysBarView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets

    var body: some View {
        ScrollViewReader { scroll in
            ZStack {
                List {
                    ActivityFilterBarView().id("top")
                    ActivityListView()
                }

                ScrollToTopView(action: { scroll.scrollTo("top", anchor: .bottom) })
                //.padding(.bottom, self.safeAreaInsets.bottom)
                .padding(.bottom, TAB_VIEW_WIDTH)
            }
        }
    }
}

struct ActivitysBarView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitysBarView()
    }
}
