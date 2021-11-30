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

struct DebugView: View {

    let vm: DebugViewModel
    @Binding var activeSheet: ActiveSheet?
    @Binding var showPreviewAllScreens: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Debug tools").font(.headline)
            Text("All actions take place").font(.caption)

            List {
                Button(action: {
                    self.activeSheet = nil
                    self.vm.activateAccount()
                }) {
                    Text("Activate account")
                }

                Button(action: {
                    self.activeSheet = nil
                    self.vm.deactivateAccount()
                }) {
                    Text("Deactivate account")
                }

                Button(action: {
                    self.activeSheet = nil
                    onBackground {
                        sleep(5)
                        onMain {
                            self.activeSheet = .rate
                        }
                    }
                }) {
                    Text("Show rate us screen")
                }

                Button(action: {
                    self.activeSheet = nil
                    onBackground {
                        sleep(5)
                        onMain {
                            self.vm.resetPacks()
                        }
                    }
                }) {
                    Text("Reset packs")
                }

                Button(action: {
                   self.activeSheet = nil
                   onBackground {
                       sleep(5)
                       onMain {
                        InboxService.shared.resetChat()
                       }
                   }
               }) {
                   Text("Reset chat")
               }

                Button(action: {
                    self.activeSheet = nil
                    onBackground {
                        sleep(5)
                        onMain {
                            self.vm.activateFakeAdCounter()
                        }
                    }
                }) {
                    Text("Activate random ads counter")
                }

                Button(action: {
                    self.activeSheet = nil
                    onBackground {
                        sleep(5)
                        onMain {
                            self.showPreviewAllScreens = true
                        }
                    }
                }) {
                    Text("Active all screens slide show")
                }
            }
        }
        .padding()
    }
}

struct DebugView_Previews: PreviewProvider {
    static var previews: some View {
        DebugView(vm: DebugViewModel(homeVM: HomeViewModel()), activeSheet: .constant(nil), showPreviewAllScreens: .constant(false))
    }
}
