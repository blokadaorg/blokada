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

struct JournalListView: View {

    @ObservedObject var journal = ViewModels.journal
    @ObservedObject var custom = ViewModels.custom
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        ForEach(self.journal.entries, id: \.self) { entry in
            Button(action: {
                self.tabVM.setSection(entry.id)
            }) {
                JournalItemView(vm: JournalItemViewModel(entry: entry))
                    .listRowInsets(EdgeInsets())
                    .contextMenu {
                        if self.custom.whitelist.contains(entry.entry.domainName) {
                            Button(action: {
                                self.custom.delete(entry.entry.domainName)
                            }) {
                                Text(L10n.activityActionRemoveFromWhitelist)
                                Image(systemName: "shield.slash")
                            }
                        } else if self.custom.blacklist.contains(entry.entry.domainName) {
                            Button(action: {
                                self.custom.delete(entry.entry.domainName)
                            }) {
                                Text(L10n.activityActionRemoveFromBlacklist)
                                Image(systemName: "shield.slash")
                            }
                        } else if entry.entry.type == .blocked {
                            Button(action: {
                                self.custom.allow(entry.entry.domainName)
                            }) {
                                Text(L10n.activityActionAddToWhitelist)
                                Image(systemName: "shield.slash")
                            }
                        } else {
                            Button(action: {
                                self.custom.deny(entry.entry.domainName)
                            }) {
                                Text(L10n.activityActionAddToBlacklist)
                                Image(systemName: "shield.slash")
                            }
                        }
                        Button(action: {
                            UIPasteboard.general.string = entry.entry.domainName
                        }) {
                            Text(L10n.activityActionCopyToClipboard)
                            Image(systemName: Image.fCopy)
                        }
                    }
            }
        }
    }
}

struct JournalListView_Previews: PreviewProvider {
    static var previews: some View {
        JournalListView()
    }
}
