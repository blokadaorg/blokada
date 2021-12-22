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

struct ContentView: View {

    @ObservedObject var homeVM = ViewModels.home
    @ObservedObject var vm = ViewModels.content

    @State var showPreviewAllScreens = false

    var body: some View {
        // Set accent color on all switches
        UISwitch.appearance().onTintColor = UIColor(named: "Orange")

        return GeometryReader { geometry in
            ZStack {
                MainView()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .padding(.top, geometry.safeAreaInsets.top)
                    .sheet(item: self.$vm.activeSheet, onDismiss: { self.vm.dismissSheet() }) { item in
                        switch item {
                        case .Payment:
                            PaymentGatewayView()
                        case .Location:
                            LocationListView()
                        case .Activated:
                            AfterActivatedView()
                        case .AskForVpn:
                            AskVpnProfileView()
                        case .EncryptionExplain:
                            EncryptionExplanationView(level: self.homeVM.encryptionLevel)
                        case .ShowLog:
                            LogView()
                        case .ShareLog:
                            ShareSheet(activityItems: [LoggerSaver.logFile])
                        case .Debug:
                            DebugView(showPreviewAllScreens: self.$showPreviewAllScreens)
                        case .RateApp:
                            RateAppView()
                        case .AdsCounter:
                            AdsCounterShareView()
                        case .ShareAdsCounter:
                            ShareSheet(activityItems: [L10n.mainShareMessage(self.homeVM.blockedCounter.compact)])
                        case .Help:
                            SupportView()
                        case .DnsProfileCta:
                            DnsProfileConfiguredView()
                        }
                    }
                }
                .background(Color.cBackground)

//            if self.showPreviewAllScreens {
//                PreviewAllScreensView(showPreviewAllScreens: self.$showPreviewAllScreens)
//                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
//                    .padding(.top, geometry.safeAreaInsets.top)
//                    .background(Color.cBackground)
//                    .opacity(self.showPreviewAllScreens ? 1 : 0)
//                    .transition(.opacity)
//                    .animation(.easeInOut)
//            }

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
        .background(Color.cSecondaryBackground.edgesIgnoringSafeArea(.all))
        .edgesIgnoringSafeArea(.top)
        .alert(isPresented: self.$homeVM.showError) {
            Alert(title: Text(self.homeVM.errorHeader ?? L10n.alertErrorHeader), message: Text(self.homeVM.showErrorMessage()),
                  dismissButton: Alert.Button.default(
                    Text(L10n.universalActionClose), action: { self.homeVM.error = nil }
                )
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let homeVM = HomeViewModel()
        homeVM.showSplash = false

        return Group {
            ContentView(homeVM: homeVM)
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            .environment(\.colorScheme, .dark)
            
            ContentView(homeVM: homeVM)

            ContentView(homeVM: homeVM)
            .environment(\.sizeCategory, .extraExtraExtraLarge)
            .environment(\.colorScheme, .dark)

            ContentView(homeVM: homeVM)
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (3rd generation)"))
        }
    }
}
