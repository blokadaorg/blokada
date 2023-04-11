//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct JournalNarrowView: View {

    @ObservedObject var journal = ViewModels.journal
    @ObservedObject var custom = ViewModels.custom
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        GeometryReader { geo in
            NavigationStack(path: self.$journal.sectionStack) {
                ZStack {
                    if self.journal.logRetention != "" {
                        List {
                            JournalFilterBarView().id("top-journal")
                            ForEach(self.journal.entries, id: \.self) { entry in
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
                                .background(
                                    NavigationLink("", value: entry).opacity(0)
                                )
                            }
                        }
                    } else {
                        NoLogRetentionView()
                    }
                }
                .navigationDestination(for: UiJournalEntry.self) { entry in
                    JournalDetailView(vm: JournalItemViewModel(entry: entry))
                }
                .navigationBarTitle(L10n.activitySectionHeader)
                .padding(.bottom, 48)

            }
            .accentColor(Color.cAccent)
        }
    }
}

struct JournalNarrowView_Previews: PreviewProvider {
    static var previews: some View {
        JournalNarrowView()
    }
}
