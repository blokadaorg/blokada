//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct ContentView: View {

    let accountVM: AccountViewModel
    let tabVM: TabViewModel
    let paymentVM: PaymentGatewayViewModel
    let locationVM: LocationListViewModel
    let logVM: LogViewModel
    let packsVM: PacksViewModel
    let activityVM: ActivityViewModel
    let inboxVM: InboxViewModel
    let leaseVM: LeaseListViewModel

    @ObservedObject var vm: HomeViewModel

    @State var showPreviewAllScreens = false
    @State var showSheet = false
    @State var sheet = "none"

    var body: some View {
        // Set accent color on all switches
        UISwitch.appearance().onTintColor = UIColor(named: "Orange")

        return GeometryReader { geometry in
            ZStack {
                MainView(accountVM: self.accountVM, packsVM: self.packsVM, activityVM: self.activityVM, vm: self.vm, inboxVM: self.inboxVM, leaseVM: self.leaseVM, tabVM: self.tabVM,
                         showSheet: self.$showSheet, sheet: self.$sheet)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .padding(.top, geometry.safeAreaInsets.top)
                    .sheet(isPresented: self.$showSheet) {
                        if self.sheet == "plus" {
                            PaymentGatewayView(vm: self.paymentVM, showSheet: self.$showSheet, sheet: self.$sheet)
                        } else if self.sheet == "location" {
                            LocationListView(vm: self.locationVM, showSheet: self.$showSheet)
                        } else if self.sheet == "activated" {
                            AfterActivatedView(showSheet: self.$showSheet, sheet: self.$sheet)
                        } else if self.sheet == "askvpn" {
                            AskVpnProfileView(homeVM: self.vm, showSheet: self.$showSheet)
                        } else if self.sheet == "encryption-explain" {
                            EncryptionExplanationView(showSheet: self.$showSheet, sheet: self.$sheet, vm: self.vm, level: self.vm.encryptionLevel)
                        } else if self.sheet == "log" {
                            LogView(vm: self.logVM, showSheet: self.$showSheet, sheet: self.$sheet)
                        } else if self.sheet == "sharelog" {
                            ShareSheet(activityItems: [LoggerSaver.logFile])
                        } else if self.sheet == "debug" {
                            DebugView(vm: DebugViewModel(homeVM: self.vm), showSheet: self.$showSheet, sheet: self.$sheet, showPreviewAllScreens: self.$showPreviewAllScreens)
                        } else if self.sheet == "rate" {
                            RateAppView(showSheet: self.$showSheet)
                        } else if self.sheet == "counter" {
                            AdsCounterShareView(homeVM: self.vm, sheet: self.$sheet, showSheet: self.$showSheet)
                        } else if self.sheet == "sharecounter" {
                            ShareSheet(activityItems: [L10n.mainShareMessage(self.vm.blockedCounter.compact)])
                        } else if self.sheet == "help" {
                            SupportView(showSheet: self.$showSheet)
                        } else {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    SpinnerView()
                                    Spacer()
                                }
                                Spacer()
                            }
                            .background(Color.cBackground)
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
                .opacity(self.vm.showSplash ? 1 : 0)
            SplashView()
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .opacity(self.vm.showSplash ? 1 : 0)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5))
        }
        .background(Color.cSecondaryBackground.edgesIgnoringSafeArea(.all))
        .edgesIgnoringSafeArea(.top)
        .alert(isPresented: self.$vm.showError) {
            Alert(title: Text(self.vm.errorHeader ?? L10n.alertErrorHeader), message: Text(self.vm.showErrorMessage()),
                  dismissButton: Alert.Button.default(
                    Text(L10n.universalActionClose), action: { self.vm.error = nil }
                )
            )
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let tabVM = TabViewModel()
        let homeVM = HomeViewModel()
        homeVM.showSplash = false

        return Group {
            ContentView(
                accountVM: AccountViewModel(),
                tabVM: tabVM,
                paymentVM: PaymentGatewayViewModel(),
                locationVM: LocationListViewModel(),
                logVM: LogViewModel(),
                packsVM: PacksViewModel(tabVM: tabVM),
                activityVM: ActivityViewModel(),
                inboxVM: InboxViewModel(),
                leaseVM: LeaseListViewModel(),
                vm: HomeViewModel()
            )
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            .environment(\.colorScheme, .dark)

            ContentView(
                accountVM: AccountViewModel(),
                tabVM: tabVM,
                paymentVM: PaymentGatewayViewModel(),
                locationVM: LocationListViewModel(),
                logVM: LogViewModel(),
                packsVM: PacksViewModel(tabVM: tabVM),
                activityVM: ActivityViewModel(),
                inboxVM: InboxViewModel(),
                leaseVM: LeaseListViewModel(),
                vm: HomeViewModel()
            )

            ContentView(
                accountVM: AccountViewModel(),
                tabVM: tabVM,
                paymentVM: PaymentGatewayViewModel(),
                locationVM: LocationListViewModel(),
                logVM: LogViewModel(),
                packsVM: PacksViewModel(tabVM: tabVM),
                activityVM: ActivityViewModel(),
                inboxVM: InboxViewModel(),
                leaseVM: LeaseListViewModel(),
                vm: HomeViewModel()
            )
            .environment(\.sizeCategory, .extraExtraExtraLarge)
            .environment(\.colorScheme, .dark)

            ContentView(
                accountVM: AccountViewModel(),
                tabVM: tabVM,
                paymentVM: PaymentGatewayViewModel(),
                locationVM: LocationListViewModel(),
                logVM: LogViewModel(),
                packsVM: PacksViewModel(tabVM: tabVM),
                activityVM: ActivityViewModel(),
                inboxVM: InboxViewModel(),
                leaseVM: LeaseListViewModel(),
                vm: homeVM
            )
            .previewDevice(PreviewDevice(rawValue: "iPad Pro (12.9-inch) (3rd generation)"))
        }
    }
}
