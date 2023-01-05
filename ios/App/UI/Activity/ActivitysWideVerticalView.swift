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

struct ActivitysWideVerticalView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var vm = ViewModels.activity
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    if self.vm.logRetention != "" {
                        ActivitysNoBarView() // Not sure why
                    } else {
                        NoLogRetentionView()
                    }
                }
                .frame(width: 400)
                .padding(.bottom, 56 + self.safeAreaInsets.bottom)

                ZStack {
                    if let it = self.tabVM.section as? HistoryEntry {
                        ActivityDetailView(
                            vm: ActivityItemViewModel(entry: it)
                        )  
                    } else {
                        PlaceholderPaneView(title: L10n.mainTabActivity)
                    }
                }
                .padding(.top, self.safeAreaInsets.top)
                .background(Color.cBackground)
            }
            TopBarBlurView()
        }
    }
}

struct ActivitysWideVerticalView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitysWideVerticalView()
    }
}
