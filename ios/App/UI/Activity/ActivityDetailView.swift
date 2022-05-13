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

struct ActivityDetailView: View {

    @ObservedObject var vm: ActivityItemViewModel
    @ObservedObject var activityVM = ViewModels.activity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    ZStack {
                        Image(systemName: vm.entry.type == .whitelisted ? "shield.slash"  : "shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .foregroundColor(vm.entry.type == .blocked ? .red : .green)
                    }

                    VStack(alignment: .leading) {
                        Text(self.vm.entry.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.system(size: 22))
                        (
                            Text(getActionStringForEntry(it: self.vm.entry))
                        )
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                    }
                    .accessibilitySortPriority(1)
                    .frame(height: 96)
                    .padding(.leading, 10)
                }

                Divider()

                Text(L10n.activityActionsHeader)
                    .font(.system(size: 20))
                    .bold()
                    .padding(.bottom)

                    VStack(spacing: 0) {
                        if self.vm.whitelisted {
                            Button(action: {
                                self.activityVM.unallow(self.vm.entry)
                            }) {
                                OptionView(
                                    text: L10n.activityActionAddedToWhitelist,
                                    image: Image.fShieldSlash,
                                    active: true
                                )
                            }
                        } else if self.vm.blacklisted {
                            Button(action: {
                                self.activityVM.undeny(self.vm.entry)
                            }) {
                                OptionView(
                                    text: L10n.activityActionAddedToBlacklist,
                                    image: Image.fShieldSlash,
                                    active: true
                                )
                            }
                            
                        } else if self.vm.entry.type == HistoryEntryType.passed {
                            Button(action: {
                                self.activityVM.deny(self.vm.entry)
                            }) {
                                OptionView(
                                    text: L10n.activityActionAddToBlacklist,
                                    image: Image.fShieldSlash,
                                    active: false
                                )
                            }
                        } else {
                            Button(action: {
                                self.activityVM.allow(self.vm.entry)
                            }) {
                                OptionView(
                                    text: L10n.activityActionAddToWhitelist,
                                    image: Image.fShieldSlash,
                                    active: false
                                )
                            }
                        }

                        Button(action: {
                            UIPasteboard.general.string = self.vm.entry.name
                        }) {
                            OptionView(
                                text: L10n.activityActionCopyToClipboard,
                                image: Image.fCopy,
                                active: false
                            )
                        }
                    }
                    .padding(.bottom)

                Divider()

                Text(L10n.activityInformationHeader)
                    .font(.system(size: 20))
                    .bold()
                    .padding(.bottom)

                VStack(alignment: .leading) {
                    Text(L10n.activityDomainName)
                        .foregroundColor(.secondary)
                    Text(self.vm.entry.name)
                }
                .font(.footnote)
                .padding(.bottom)

                VStack(alignment: .leading) {
                    Text(L10n.activityTimeOfOccurrence)
                        .foregroundColor(.secondary)
                    Text(self.vm.entry.time.human)
                }
                .font(.footnote)
                .padding(.bottom)

                VStack(alignment: .leading) {
                    Text(L10n.activityNumberOfOccurrences)
                        .foregroundColor(.secondary)
                    Text(String(self.vm.entry.requests))
                }
                .font(.footnote)
                .padding(.bottom)

                VStack(alignment: .leading) {
                    Text(L10n.universalLabelDevice)
                        .foregroundColor(.secondary)
                    Text(String(self.vm.entry.device))
                }
                .font(.footnote)
                .padding(.bottom)
            }
            .padding()
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .accentColor(Color.cAccent)
    }
}

private func getActionStringForEntry(it: HistoryEntry) -> String {
    if it.type == .whitelisted {
        return L10n.activityRequestAllowedWhitelisted
    } else if it.type == .blocked && it.list == Services.env.deviceTag {
        return L10n.activityRequestBlockedBlacklisted
    } else if it.type == .blocked && it.list != nil {
        return L10n.activityRequestBlockedList(it.list!)
    } else if it.type == .blocked {
        return L10n.activityRequestBlocked
    } else if it.type == .whitelisted && it.list == Services.env.deviceTag {
        return L10n.activityRequestAllowedWhitelisted
    } else if it.type == .passed && it.list != nil {
        return L10n.activityRequestAllowedList(it.list!)
    } else {
        return L10n.activityRequestAllowed
    }
}

struct ActivityDetailView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ActivityDetailView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "example.com",
                type: .whitelisted,
                time: Date(timeIntervalSinceNow: -50000),
                requests: 458,
                device: "iphone",
                list: "OISD"
            )))

            ActivityDetailView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "example.com",
                type: .passed,
                time: Date(timeIntervalSinceNow: -50000),
                requests: 458,
                device: "iphone",
                list: "OISD"
            )))

            ActivityDetailView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.boring.name.of.example.com",
                type: .blocked,
                time: Date(timeIntervalSinceNow: -5),
                requests: 1,
                device: "iphone",
                list: nil
            )))

            ActivityDetailView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.boring.name.of.example.com",
                type: .blocked,
                time: Date(timeIntervalSinceNow: -5),
                requests: 1,
                device: "iphone",
                list: "Goodbye"
            )))
        }
    }
}
