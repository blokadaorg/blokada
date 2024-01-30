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
        ScrollViewReader { scroll in
            GeometryReader { geo in
                if geo.size.height > geo.size.width {
                    // Portrait, tab bar at the bottom, overlapping content
                    ZStack {
                        // Small width portrait, like iPhone or iPad with split screen
                        if geo.size.width < 700 {
                            ZStack {
                                //RippleView(multiplier: 1.2)

                                FlutterHomeView().opacity(self.tabVM.activeTab == .Home ? 1 : 0)

                                ShieldsNarrowView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                                JournalNarrowView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                                SettingsNarrowView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                            }
                        // Big width portrait, like iPad fullscreen
                        } else {
                            ZStack {
                                //RippleView(multiplier: 2.0)

                                FlutterHomeView().opacity(self.tabVM.activeTab == .Home ? 1 : 0)

                                ShieldsWideView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                                JournalWideVerticalView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                                SettingsWideVerticalView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                            }
                        }
                        VStack {
                            Spacer()
                            if tabVM.showNavBar {
                                TabHorizontalView(onTap: { it in
                                    handleTappedTab(it, scroll: scroll)
                                })
                            }
                        }
                        // Hacky way to show the action sheet that works on ios 15
                        Text("")
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .actionSheet(isPresented: self.$vm.showPauseMenu) {
                            ActionSheet(title: Text(L10n.homePowerOffMenuHeader), buttons: [
                                .default(Text(self.homeVM.isPaused ? L10n.homePowerActionTurnOn : L10n.homePowerActionPause)) {
                                    if self.homeVM.isPaused {
                                        self.homeVM.unpause()
                                    } else if !self.homeVM.notificationPermsGranted {
                                        self.homeVM.displayNotificationPermsInstructions()
                                    } else {
                                        self.homeVM.pause(seconds: PAUSE_TIME_SECONDS)
                                    }
                                },
                                .destructive(Text(L10n.homePowerActionTurnOff)) {
                                    self.homeVM.pause(seconds: nil)
                                },
                                .cancel()
                            ])
                        }
                    }
                } else {
                    // Small width landscape, like iPad with split screen in landscape
                    if geo.size.width < 800 {
                        ZStack {
                            //RippleView(multiplier: 2.0)

                            ZStack {
                                FlutterHomeView().opacity(self.tabVM.activeTab == .Home ? 1 : 0)

                                ShieldsNarrowView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                                JournalWideVerticalView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                                SettingsWideVerticalView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                            }
                            VStack {
                                Spacer()
                                if tabVM.showNavBar {
                                    TabHorizontalView(onTap: { it in
                                        handleTappedTab(it, scroll: scroll)
                                    })
                                }
                            }
                            // Hacky way to show the action sheet that works on ios 15
                            Text("")
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .actionSheet(isPresented: self.$vm.showPauseMenu) {
                                ActionSheet(title: Text(L10n.homePowerOffMenuHeader), buttons: [
                                    .default(Text(self.homeVM.isPaused ? L10n.homePowerActionTurnOn : L10n.homePowerActionPause)) {
                                        if self.homeVM.isPaused {
                                            self.homeVM.unpause()
                                        } else if !self.homeVM.notificationPermsGranted {
                                            self.homeVM.displayNotificationPermsInstructions()
                                        } else {
                                            self.homeVM.pause(seconds: PAUSE_TIME_SECONDS)
                                        }
                                    },
                                    .destructive(Text(L10n.homePowerActionTurnOff)) {
                                        self.homeVM.pause(seconds: nil)
                                    },
                                    .cancel()
                                ])
                            }
                        }
                    } else {
                        // Landscape, tab bar on the left, next to content
                        ZStack {
                            HStack(spacing: 0) {
                                if tabVM.showNavBar {
                                    TabVerticalView(onTap: { it in
                                        handleTappedTab(it, scroll: scroll)
                                    })
                                }
                                ZStack {
                                    //RippleView(multiplier: 1.5)

                                    FlutterHomeView().opacity(self.tabVM.activeTab == .Home ? 1 : 0)

                                    ShieldsWideView().opacity(self.tabVM.activeTab == .Advanced ? 1 : 0)
                                    JournalWideHorizontalView().opacity(self.tabVM.activeTab == .Activity ? 1 : 0)
                                    SettingsWideHorizontalView().opacity(self.tabVM.activeTab == .Settings ? 1 : 0)
                                    
                                    // Hacky way to show the action sheet that works on ios 15
                                    Text("")
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    .actionSheet(isPresented: self.$vm.showPauseMenu) {
                                        ActionSheet(title: Text(L10n.homePowerOffMenuHeader), buttons: [
                                            .default(Text(self.homeVM.isPaused ? L10n.homePowerActionTurnOn : L10n.homePowerActionPause)) {
                                                if self.homeVM.isPaused {
                                                    self.homeVM.unpause()
                                                } else if !self.homeVM.notificationPermsGranted {
                                                    self.homeVM.displayNotificationPermsInstructions()
                                                } else {
                                                    self.homeVM.pause(seconds: PAUSE_TIME_SECONDS)
                                                }
                                            },
                                            .destructive(Text(L10n.homePowerActionTurnOff)) {
                                                self.homeVM.pause(seconds: nil)
                                            },
                                            .cancel()
                                        ])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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
