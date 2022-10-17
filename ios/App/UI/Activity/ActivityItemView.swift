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

struct ActivityItemView: View {

    @ObservedObject var vm: ActivityItemViewModel

    var body: some View {
        HStack {
            Rectangle()
            .fill(vm.entry.type == .blocked ? Color.red : Color.clear)
            .frame(width: 3)

            ZStack {
                ZStack {
                    Image(systemName: vm.entry.type == .whitelisted ? "shield.slash"  : "shield")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .foregroundColor(vm.entry.type == .blocked ? .red : .green)

                    if vm.entry.type != .whitelisted {
                        Text(vm.entry.requests.upTo99)
                        .font(.system(size: 13))
                        .foregroundColor(Color.primary)
                    }
                }
            }
            .frame(width: 44)
            .accessibilityLabel("\(vm.entry.requests)")

            VStack(alignment: .leading) {
                Text(vm.entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(self.vm.selected ? Color.cAccent : Color.primary)

                HStack {
                    Text(vm.entry.time.relative)
                    if (vm.entry.type == .whitelisted) != vm.whitelisted || (vm.entry.type == .passed) && vm.blacklisted {
                        Spacer()
                        Text(L10n.activityStateModified)
                    }
                }
                .font(.footnote)
                .foregroundColor(Color.secondary)

                (
                    Text(vm.entry.type == .blocked ? L10n.activityStateBlocked : L10n.activityStateAllowed)
                        + Text(" " + (vm.entry.requests == 1 ? L10n.activityHappenedOneTime : L10n.activityHappenedManyTimes(vm.entry.requests.compact)))
                )
                    .font(.footnote)
                    .foregroundColor(Color.secondary)
            }
            Spacer()
        }
        .frame(height: 54)
        .padding([.bottom, .top], 10)
        .padding([.trailing], 16)
        .opacity((vm.entry.type == .whitelisted) != vm.whitelisted || (vm.entry.type == .passed) && vm.blacklisted ? 0.5 : 1)
    }
}

struct ActivityItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "doubleclick.com.",
                type: .blocked,
                time: Date(),
                requests: 1,
                device: "iphone",
                list: "OISD"
            )))
            .previewLayout(.sizeThatFits)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.domain.name.com.",
                type: .whitelisted,
                time: Date(timeIntervalSinceNow: -5),
                requests: 1,
                device: "iphone",
                list: nil
            )))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraExtraExtraLarge)
            .environment(\.colorScheme, .dark)
            .background(Color.black)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "google.com.",
                type: .passed,
                time: Date(timeIntervalSinceNow: -5),
                requests: 999999999,
                device: "iphone",
                list: "OISD"
            )))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraSmall)
            .environment(\.colorScheme, .dark)
            .background(Color.black)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.domain.name.com",
                type: .blocked,
                time: Date(timeIntervalSinceNow: -5000000),
                requests: 999999,
                device: "iphone",
                list: "OISD"
            )))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraExtraExtraLarge)
        }
    }
}
