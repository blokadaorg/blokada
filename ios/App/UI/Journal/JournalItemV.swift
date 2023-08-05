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

struct JournalItemView: View {

    @ObservedObject var vm: JournalItemViewModel

    var body: some View {
        HStack {
            Rectangle()
            .fill(vm.entry.entry.type == .blocked ? Color.red : Color.clear)
            .frame(width: 3)

            ZStack {
                ZStack {
                    Image(systemName: vm.entry.entry.type == .passedAllowed ? "shield.slash"  : "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .foregroundColor(vm.entry.entry.type == .blocked || vm.entry.entry.type == .blockedDenied ? .red : .green)

                    if vm.entry.entry.type != .passedAllowed {
                        Text(vm.entry.entry.requests.upTo99)
                        .font(.system(size: 13))
                        .foregroundColor(Color.primary)
                    }
                }
            }
            .frame(width: 44)
            .accessibilityLabel("\(vm.entry.entry.requests)")

            VStack(alignment: .leading) {
                Text(vm.entry.entry.domainName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(self.vm.selected ? Color.cAccent : Color.primary)

                HStack {
                    Text(vm.entry.time.relative)
                    if (vm.entry.entry.type == .passedAllowed) != vm.whitelisted || (vm.entry.entry.type == .passed) && vm.blacklisted {
                        Spacer()
                        Text(L10n.activityStateModified)
                    }
                }
                .font(.footnote)
                .foregroundColor(Color.secondary)

                (
                    Text(vm.entry.entry.type == .blocked ? L10n.activityStateBlocked : L10n.activityStateAllowed)
                        + Text(" " + (vm.entry.entry.requests == 1 ? L10n.activityHappenedOneTime : L10n.activityHappenedManyTimes(vm.entry.entry.requests.compact)))
                )
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
            }
            Spacer()

            ShieldIconView(id: self.vm.entry.entry.deviceName,  title: self.vm.entry.entry.deviceName, small: true)
                .frame(width: 32, height: 32)
                .mask(RoundedRectangle(cornerRadius: 8))
                .accessibilityLabel(self.vm.entry.entry.deviceName)
        }
        .frame(height: 54)
        .padding([.bottom, .top], 10)
        .padding([.trailing], 16)
        .opacity((vm.entry.entry.type == .passedAllowed) != vm.whitelisted || (vm.entry.entry.type == .passed) && vm.blacklisted ? 0.5 : 1)
    }
}

struct JournalItemView_Previews: PreviewProvider {
    static var previews: some View {
        JournalItemView(vm: JournalItemViewModel(entry: UiJournalEntry(entry: JournalEntry(domainName: "example.com", type: .blocked, time: "", requests: 123, deviceName: "iphone"), time: Date())))
        .previewLayout(.sizeThatFits)
    }
}
