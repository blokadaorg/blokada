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

    let vm = DebugViewModel(homeVM: ViewModels.home)
    @ObservedObject var contentVM = ViewModels.content

    @Binding var showPreviewAllScreens: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Debug tools").font(.headline)
            Text("All actions take place").font(.caption)

            List {
                Button(action: {
                    self.contentVM.dismissSheet()
                    self.vm.activateAccount()
                }) {
                    Text("Activate account")
                }

                Button(action: {
                    self.contentVM.dismissSheet()
                    self.vm.deactivateAccount()
                }) {
                    Text("Deactivate account")
                }

                Button(action: {
                    self.contentVM.dismissSheet()

                    onBackground {
                        sleep(5)
                        onMain {
                            self.contentVM.showSheet(.RateApp)
                        }
                    }
                }) {
                    Text("Show rate us screen")
                }

                Button(action: {
                    self.contentVM.dismissSheet()

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
                    self.contentVM.dismissSheet()
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
                    self.contentVM.dismissSheet()
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
                    self.contentVM.dismissSheet()
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
        DebugView(showPreviewAllScreens: .constant(false))
    }
}
