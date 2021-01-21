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

struct PreviewAllScreensView: View {

    @Binding var showPreviewAllScreens: Bool

    private let slidesCount = 13

    @State var counter = 0 {
        didSet {
            if counter < self.slidesCount {
                afterDelay {
                    // Showing controls pauses the slideshow
                    if !self.showControls {
                        self.counter = self.counter + 1
                    }
                }
            } else {
                self.showControls = true
            }
        }
    }

    @State var showControls = false

    var body: some View {
        let defaultHomeVM = HomeViewModel()
        defaultHomeVM.mainSwitch = true
        defaultHomeVM.vpnEnabled = true
        defaultHomeVM.accountActive = true

        let defaultAccountVM = AccountViewModel()
        defaultAccountVM.account = Account(id: "", active_until: "2069-03-15T11:38:38.48383Z", active: true)

        let defaultActivityVM = ActivityViewModel()
        let defaultTabVM = TabViewModel()
        let defaultPacksVM = PacksViewModel(tabVM: defaultTabVM)

        let vmAdsCounter = HomeViewModel()
        vmAdsCounter.blockedCounter = 238348

        let vmWorking = HomeViewModel()
        vmWorking.working = true

        return ZStack {
            if counter == 0 {
                SplashView()
            } else if counter == 1 {
                List {
                    Text(errorDescriptions[CommonError.deviceOffline]!)
                    Text(errorDescriptions[CommonError.accountInactive]!)
                    Text(errorDescriptions[CommonError.failedCreatingAccount]!)
                    Text(errorDescriptions[CommonError.failedFetchingData]!)
                    Text(errorDescriptions[CommonError.failedTunnel]!)
                    Text(errorDescriptions[CommonError.failedVpn]!)
                    Text(errorDescriptions[CommonError.vpnNoPermissions]!)
                    Text(errorDescriptions[CommonError.noCurrentLease]!)
                    Text(errorDescriptions[CommonError.tooManyLeases]!)
                }
                .padding()
            } else if counter == 2 {
                List {
                    Text(errorDescriptions[CommonError.paymentInactiveAfterRestore]!)
                    Text(errorDescriptions[CommonError.paymentFailed]!)
                    Text(errorDescriptions[CommonError.paymentFailed]!)
                    Text(errorDescriptions[CommonError.paymentCancelled]!)
                    Text(errorDescriptions[CommonError.paymentNotAvailable]!)
                }
                .padding()
            } else if counter == 3 {
                List {
                    Text(L10n.errorPackInstall)
                    Text(L10n.errorLocationFailedFetching)
                    Text(errorDescriptions[CommonError.unknownError]!)
                    Text(L10n.alertErrorHeader)
                    Text(L10n.alertVpnExpiredHeader)
                    Text(L10n.universalActionCancel)
                    Text(L10n.universalActionCopy)
                    Text(L10n.universalActionSave)
                    Text(L10n.universalActionContactUs)
                    Text(L10n.universalLabelHelp)
                }
                .padding()
            } else if counter == 4 {
                List {
                    Text(L10n.universalActionContinue)
                    Text(L10n.universalActionCancel)
                    Text(L10n.universalActionClose)
                    Text(L10n.universalActionDone)
                    Text(L10n.universalActionTryAgain)
                    Text(L10n.universalActionLearnMore)
                    Text(L10n.universalActionHelp)
                    Text(L10n.universalActionShowLog)
                    Text(L10n.universalActionShareLog)
                    Text(L10n.universalActionCancel)
                }
                .padding()
            } else if counter == 5 {
                AskVpnProfileView(homeVM: defaultHomeVM, activeSheet: .constant(nil))
            } else if counter == 6 {
                RateAppView(activeSheet: .constant(nil))
            } else if counter == 7 {
                AdsCounterShareView(homeVM: vmAdsCounter, activeSheet: .constant(nil))
            } else if counter == 8 {
                MainView(
                      accountVM: defaultAccountVM,
                      packsVM: defaultPacksVM,
                      activityVM: defaultActivityVM,
                      vm: defaultHomeVM,
                      inboxVM: InboxViewModel(),
                      leaseVM: LeaseListViewModel(),
                      tabVM: defaultTabVM,
                      activeSheet: .constant(nil)
                  )
            } else if counter == 9 {
                LocationListView(activeSheet: .constant(nil))
            } else if counter == 10 {
                SettingsTabView(
                    homeVM: defaultHomeVM,
                    vm: defaultAccountVM,
                    tabVM: defaultTabVM,
                    inboxVM: InboxViewModel(),
                    leaseVM: LeaseListViewModel(),
                    activeSheet: .constant(nil)
                )
            } else if counter == 11 {
                EncryptionExplanationView(
                    activeSheet: .constant(nil),
                    vm: defaultHomeVM,
                    level: 3
                )
            } else if counter == 12 {
                AfterActivatedView(
                    activeSheet: .constant(nil)
                )
            } else {
                EmptyView()
            }

            VStack {
                Spacer()
                Text(String(self.counter + 1) + " of " + String(self.slidesCount))
                HStack {
                    Button(action: {
                        self.counter = max(0, self.counter - 1)
                    }) { Text("<< Prev") }
                    Spacer()
                    Button(action: {
                        self.showPreviewAllScreens = false
                    }) {
                        Text("Quit")
                    }
                    Spacer()
                    Button(action: {
                        self.counter = min(self.slidesCount - 1, self.counter + 1)
                    }) { Text("Next >>") }
                }
                .padding()
            }
            .accentColor(Color.cAccent)
            .padding()
            .background(Color.cBackground)
            .opacity(self.showControls ? 0.8 : 0.0)
            .transition(.opacity)
            .animation(.easeInOut)
            .contentShape(Rectangle())
            .onTapGesture {
                if self.showControls {
                    self.showControls = false
                    // Resume slideshow
//                    if self.counter < self.slidesCount {
//                        self.counter = self.counter - 1 + 1 // A trick to trigger didSet
//                    }
                } else {
                    self.showControls = true
                }
            }
        }
        .onAppear {
            self.counter = 0
        }
    }
}

private func afterDelay(callback: @escaping () -> Void) {
    onBackground {
        sleep(3)
        onMain {
            callback()
        }
    }
}

struct PreviewAllScreensView_Previews: PreviewProvider {
    static var previews: some View {
        PreviewAllScreensView(showPreviewAllScreens: .constant(false))
    }
}
