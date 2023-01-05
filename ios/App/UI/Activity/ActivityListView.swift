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

struct ActivityListView: View {

    @ObservedObject var vm = ViewModels.activity
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        ForEach(self.vm.entries, id: \.self) { entry in
            Button(action: {
                self.tabVM.setSection(entry)
            }) {
                ActivityItemView(vm: ActivityItemViewModel(entry: entry))
                    .listRowInsets(EdgeInsets())
                    .contextMenu {
                        if self.vm.whitelist.contains(entry.name) {
                            Button(action: {
                                self.vm.unallow(entry)
                            }) {
                                Text(L10n.activityActionRemoveFromWhitelist)
                                Image(systemName: "shield.slash")
                            }
                        } else if self.vm.blacklist.contains(entry.name) {
                            Button(action: {
                                self.vm.undeny(entry)
                            }) {
                                Text(L10n.activityActionRemoveFromBlacklist)
                                Image(systemName: "shield.slash")
                            }
                        } else if entry.type == .blocked {
                            Button(action: {
                                self.vm.allow(entry)
                            }) {
                                Text(L10n.activityActionAddToWhitelist)
                                Image(systemName: "shield.slash")
                            }
                        } else {
                            Button(action: {
                                self.vm.deny(entry)
                            }) {
                                Text(L10n.activityActionAddToBlacklist)
                                Image(systemName: "shield.slash")
                            }
                        }
                        Button(action: {
                            UIPasteboard.general.string = entry.name
                        }) {
                            Text(L10n.activityActionCopyToClipboard)
                            Image(systemName: Image.fCopy)
                        }
                    }
            }
            .background(
                NavigationLink("",
                   destination: ActivityDetailView(vm: ActivityItemViewModel(entry: entry)),
                   tag: entry,
                   selection: self.$tabVM.navActivity
                )
                .padding([.trailing], 8)
            )
        }
    }
}

struct ActivityListView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityListView()
    }
}
