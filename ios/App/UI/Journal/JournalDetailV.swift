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

struct JournalDetailView: View {

    @ObservedObject var vm: JournalItemViewModel
    @ObservedObject var packVM = ViewModels.packs
    @ObservedObject var custom = ViewModels.custom
    @ObservedObject var contentVM = ViewModels.content

    @Environment(\.colorScheme) var colorScheme

    @Injected(\.env) private var env

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    ZStack {
                        Image(systemName: vm.entry.entry.type == .passedAllowed ? "shield.slash"  : "shield")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                            .foregroundColor(vm.entry.entry.type == .blocked || vm.entry.entry.type == .blockedDenied ? .red : .green)
                    }
                    
                    VStack(alignment: .leading) {
                        Text(self.vm.entry.entry.domainName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .font(.system(size: 22))
                        (
                            Text(getActionStringForEntry(it: self.vm.entry))
                            .lineLimit(3)
                        )
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                    }
                    .accessibilitySortPriority(1)
                    .frame(height: 96)
                    .padding(.leading, 4)
                    
                    Spacer()
                }
                .padding([.leading, .trailing], 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                Text(L10n.activityActionsHeader)
                    .font(.system(size: 24))
                    .padding(.top)
                    .bold()
                
                VStack(spacing: 0) {
                    if self.vm.whitelisted {
                        OptionView(
                            text: L10n.activityActionAddedToWhitelist,
                            image: Image.fShieldSlash,
                            active: true,
                            canSpin: true,
                            action: {
                                self.custom.delete(self.vm.entry.entry.domainName)
                            }
                        )
                    } else if self.vm.blacklisted {
                        OptionView(
                            text: L10n.activityActionAddedToBlacklist,
                            image: Image.fShieldSlash,
                            active: true,
                            canSpin: true,
                            action: {
                                self.custom.delete(self.vm.entry.entry.domainName)
                            }
                        )
                    } else if self.vm.entry.entry.type == JournalEntryType.passed {
                        OptionView(
                            text: L10n.activityActionAddToBlacklist,
                            image: Image.fShieldSlash,
                            active: false,
                            canSpin: true,
                            action: {
                                self.custom.deny(self.vm.entry.entry.domainName)
                            }
                        )
                    } else {
                        OptionView(
                            text: L10n.activityActionAddToWhitelist,
                            image: Image.fShieldSlash,
                            active: false,
                            canSpin: true,
                            action: {
                                self.custom.allow(self.vm.entry.entry.domainName)
                            }
                        )
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                .padding(.bottom)

                VStack(spacing: 0) {
                    OptionView(
                        text: L10n.activityActionCopyToClipboard,
                        image: Image.fCopy,
                        active: false,
                        canSpin: true,
                        action: {
                            UIPasteboard.general.string = self.vm.entry.entry.domainName
                        }
                    )
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )


                Text(L10n.activityInformationHeader)
                    .font(.system(size: 24))
                    .padding(.top)
                    .bold()

                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        Text(L10n.activityDomainName)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.bottom, 8)

                        Text(self.vm.entry.entry.domainName)
                    }

                    Divider().padding([.top, .bottom], 12)

                    Group {
                        Text(L10n.activityTimeOfOccurrence)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.bottom, 8)

                        Text(self.vm.entry.time.human)
                    }
                    
                    Divider().padding([.top, .bottom], 12)

                    Group {
                        Text(L10n.activityNumberOfOccurrences)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.bottom, 8)
                        Text(String(self.vm.entry.entry.requests))
                    }

                    Divider().padding([.top, .bottom], 12)

                    Group {
                        Text(L10n.universalLabelDevice)
                            .foregroundColor(.secondary)
                            .font(.footnote)
                            .padding(.bottom, 8)
                        HStack {
                            ShieldIconView(id: self.vm.entry.entry.deviceName,  title: self.vm.entry.entry.deviceName, small: true)
                                .frame(width: 32, height: 32)
                                .mask(RoundedRectangle(cornerRadius: 8))
                                .accessibilityLabel(self.vm.entry.entry.deviceName)

                            Text(self.vm.entry.entry.deviceName)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
            }
            .padding()
            .padding(.bottom, 56)
        }
        .background(colorScheme == .dark ? Color.cBackground : Color.cSecondaryBackground)
        .navigationBarTitle(Text(""), displayMode: .inline)
        .accentColor(Color.cAccent)
    }

    private func getActionStringForEntry(it: UiJournalEntry) -> String {
        let type = it.entry.type
        if type == .passedAllowed {
            return L10n.activityRequestAllowedWhitelisted
        } else if type == .blockedDenied {
            return L10n.activityRequestBlockedBlacklisted
        } else if type == .blocked && !(it.entry.list?.isEmpty ?? true) {
            return L10n.activityRequestBlockedList(self.packVM.getListName(it.entry.list!))
        } else if type == .blocked {
            return L10n.activityRequestBlocked
        } else if type == .passedAllowed && it.entry.list == self.env.getDeviceTag() {
            return L10n.activityRequestAllowedWhitelisted
        } else if type == .passed && !(it.entry.list?.isEmpty ?? true) {
            return L10n.activityRequestAllowedList(self.packVM.getListName(it.entry.list!))
        } else {
            return L10n.activityRequestAllowed
        }
    }
}

struct JournalDetailV_Previews: PreviewProvider {
    static var previews: some View {
        JournalDetailView(vm: JournalItemViewModel(entry: UiJournalEntry(entry: JournalEntry(domainName: "example.com", type: .blocked, time: "", requests: 123, deviceName: "iphone"), time: Date())))
    }
}
