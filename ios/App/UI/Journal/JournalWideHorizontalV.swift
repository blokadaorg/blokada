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

struct JournalWideHorizontalView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var journal = ViewModels.journal
    @ObservedObject var tabVM = ViewModels.tab

    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ZStack {
                    if self.journal.logRetention != "" {
                        JournalNoBarView()
                    } else {
                        NoLogRetentionView()
                    }
                }
                .frame(width: 600)
                .padding(.bottom, self.safeAreaInsets.bottom)
        
                ZStack {
                    if let it = self.journal.sectionStack.first {
                        JournalDetailView(
                            vm: JournalItemViewModel(entry: it)
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

struct JournalWideHorizontalView_Previews: PreviewProvider {
    static var previews: some View {
        JournalWideHorizontalView()
    }
}
