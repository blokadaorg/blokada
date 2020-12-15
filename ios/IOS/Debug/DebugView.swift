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
