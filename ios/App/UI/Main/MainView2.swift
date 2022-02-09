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

struct MainView2: View {

    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        GeometryReader { geo in
            if geo.size.height > geo.size.width {
                // Portrait, tab bar at the bottom, overlapping content
                ZStack {
                    // Small width portrait, like iPhone or iPad with split screen
                    if geo.size.width < 700 {
                        ZStack {
                            HomeView(tabBar: true).opacity(self.tabVM.activeTab == .Home ? 1 : 0)
                            ActivitysNarrowView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                            PacksNarrowView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                            SettingsNarrowView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                        }
                    // Big width portrait, like iPad fullscreen
                    } else {
                        ZStack {
                            HomeView(tabBar: true).opacity(self.tabVM.activeTab == .Home ? 1 : 0)
                            ActivitysWideVerticalView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                            PacksWideVerticalView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                            SettingsWideVerticalView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                        }
                    }
                    VStack {
                        Spacer()
                        TabHorizontalView()
                    }
                }
            } else {
                // Landscape, tab bar on the left, next to content
                HStack(spacing: 0) {
                    TabVerticalView()
                    ZStack {
                        HomeView(tabBar: false).opacity(self.tabVM.activeTab == .Home ? 1 : 0)
                        ActivitysWideHorizontalView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                        PacksWideHorizontalView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                        SettingsWideHorizontalView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                    }
                }
            }
        }
    }

}
