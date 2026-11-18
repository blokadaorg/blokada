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

var TAB_VIEW_WIDTH = 80.0
var TAB_VIEW_HEIGHT = 56.0

struct ContentView: View {

    @ObservedObject var homeVM = ViewModels.home
    @ObservedObject var vm = ViewModels.content

    @Injected(\.commands) private var commands
    
    var accountChange = ScanQrCodeView()

    @State private var userInput = ""

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
                    case .plusLocationSelect:
                        LocationListView()
                    case .accountChange:
                        accountChange
                    default:
                        // Will never be displayed
                        EmptyView()
                    }
                }

                // We need animated and non-animated cover screen when changing orientation
                Rectangle()
                    .fill(Color.cBackground)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .opacity(self.homeVM.showSplash ? 1 : 0)
                SplashView()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .opacity(self.homeVM.showSplash || self.homeVM.hideContent ? 1 : 0)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.5))
            }
            .alert(L10n.familyRenameDevice, isPresented: self.$homeVM.showInput) {
                TextField("", text: $userInput)
                Button(L10n.universalActionCancel, action: { self.vm.stage.onDismissed() })
                Button(L10n.universalActionSave, action: submit)
            }
            // TODO: remove his global alert thing
            .alert(isPresented: self.$homeVM.showError) {
                Alert(title: Text(self.homeVM.errorHeader ?? L10n.alertErrorHeader), message: Text(self.homeVM.showErrorMessage()),
                      primaryButton: errorAlertAction(),
                      secondaryButton: Alert.Button.cancel(
                        Text(L10n.universalActionClose), action: { self.vm.stage.onDismissed() }
                    )
                )
            }
        }
        .sheet(item: self.$vm.shareContent, onDismiss: { self.vm.stage.onDismissed() }) { item in
            ShareSheet(activityItems: [item.item])
        }

        // Draw under status bar and bottom bar (we manage it ourselves)
        .edgesIgnoringSafeArea([.top, .bottom])
        .background(Color.cBackground.edgesIgnoringSafeArea(.all))
    }
    
    // Alerts that ask to contact us open the support chat instead of the log,
    // naming the alert so support knows where the user came from.
    private func errorAlertAction() -> Alert.Button {
        if let modal = self.homeVM.askSupportAlert {
            return Alert.Button.default(Text(L10n.supportActionAsk), action: {
                self.vm.stage.onDismissed()
                self.commands.execute(.askSupport, "\(modal)")
            })
        }
        return Alert.Button.default(Text(L10n.universalActionShowLog), action: {
            self.commands.execute(.shareLog)
        })
    }

    func submit() {
        //self.commands.execute(.deviceAlias, self.userInput)
        self.vm.stage.onDismissed()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        .previewDevice(PreviewDevice(rawValue: "iPhone X"))
    }
}
