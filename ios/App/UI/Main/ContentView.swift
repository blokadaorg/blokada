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
import Factory

struct ContentView: View {

    @ObservedObject var homeVM = ViewModels.home
    @ObservedObject var vm = ViewModels.content

    @Injected(\.tracer) private var tracer
    @Injected(\.stats) private var stats
    
    var onboarding = AfterActivatedView()

    var body: some View {
        // Set accent color on all switches
        UISwitch.appearance().onTintColor = UIColor(named: "Orange")

        // Root container for everything
        return ZStack {
            // Contains main content and the cover splash screen
            ZStack {
                // Needed to attach sheets to something
                ZStack {
                    // Actual screen content - manages views based on orientation etc
                    MainView()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                }
                .sheet(item: self.$vm.activeSheet, onDismiss: { self.vm.stage.onDismissed() }) { item in
                    switch item {
                    case .payment:
                        PaymentGatewayView()
                    case .plusLocationSelect:
                        LocationListView()
                    case .onboarding:
                        onboarding
                    case .adsCounterShare:
                        ShareSheet(activityItems: [L10n.mainShareMessage(stats.blockedCounter.value)])
                    case .help:
                        SupportView()
                    case .custom:
                        CustomV()
                    default:
                        // Will never be displayed
                        EmptyView()
                    }
                }
                // Works on ios16+
//                .actionSheet(isPresented: self.$vm.showPauseMenu) {
//                    ActionSheet(title: Text(L10n.homePowerOffMenuHeader), buttons: [
//                        .default(Text(self.homeVM.isPaused ? L10n.homePowerActionTurnOn : L10n.homePowerActionPause)) {
//                            if self.homeVM.isPaused {
//                                self.homeVM.unpause()
//                            } else if !self.homeVM.notificationPermsGranted {
//                                self.homeVM.displayNotificationPermsInstructions()
//                            } else {
//                                self.homeVM.pause(seconds: PAUSE_TIME_SECONDS)
//                            }
//                        },
//                        .destructive(Text(L10n.homePowerActionTurnOff)) {
//                            self.homeVM.pause(seconds: nil)
//                        },
//                        .cancel()
//                    ])
//                }

                // We need animated and non-animated cover screen when changing orientation
                Rectangle()
                    .fill(Color.cBackground)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .opacity(self.homeVM.showSplash ? 1 : 0)
                SplashView()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .opacity(self.homeVM.showSplash ? 1 : 0)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5))
            }
            // TODO: remove his global alert thing
            .alert(isPresented: self.$homeVM.showError) {
                Alert(title: Text(self.homeVM.errorHeader ?? L10n.alertErrorHeader), message: Text(self.homeVM.showErrorMessage()),
                      dismissButton: Alert.Button.default(
                        Text(L10n.universalActionClose), action: { self.vm.stage.onDismissed() }
                    )
                )
            }
        }
        .sheet(item: self.$vm.shareLog, onDismiss: { self.vm.stage.onDismissed() }) { item in
            ShareSheet(activityItems: [item])
        }

        // Draw under status bar and bottom bar (we manage it ourselves)
        .edgesIgnoringSafeArea([.top, .bottom])
        .background(Color.cBackground.edgesIgnoringSafeArea(.all))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        .previewDevice(PreviewDevice(rawValue: "iPhone X"))
    }
}
