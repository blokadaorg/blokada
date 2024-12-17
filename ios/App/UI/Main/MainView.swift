//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct MainView: View {

    @ObservedObject var vm = ViewModels.content
    @ObservedObject var tabVM = ViewModels.tab
    @ObservedObject var homeVM = ViewModels.home

    var body: some View {
        FlutterHomeView()
    }

    private func handleTappedTab(_ tab: Tab, scroll: ScrollViewProxy) {
        self.tabVM.setActiveTab(tab)

        // Scroll to top on second tap of the same tab
        if lastTappedTab == tab {
            if tab == .Activity || tab == .Advanced {
                withAnimation {
                    scroll.scrollTo(
                        (tab == .Advanced) ? "top-packs" : "top-journal",
                        anchor: .bottom
                    )
                }
            }
        }
        lastTappedTab = tab
    }

}

private var lastTappedTab: Tab? = nil

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
        .previewDevice(PreviewDevice(rawValue: "iPhone X"))
    }
}
