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

struct ActivityItemView: View {

    @ObservedObject var vm: ActivityItemViewModel

    var body: some View {
        HStack {
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
                    }
                }
            }
            .frame(width: 44)

            VStack(alignment: .leading) {
                Text(vm.entry.name)
                    .lineLimit(1)
                    .truncationMode(.middle)

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
        .padding([.leading, .trailing], 9)
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
                requests: 1
            ), whitelisted: false, blacklisted: true))
            .previewLayout(.sizeThatFits)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.domain.name.com.",
                type: .whitelisted,
                time: Date(timeIntervalSinceNow: -5),
                requests: 1
            ), whitelisted: false, blacklisted: false))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraExtraExtraLarge)
            .environment(\.colorScheme, .dark)
            .background(Color.black)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "google.com.",
                type: .passed,
                time: Date(timeIntervalSinceNow: -5),
                requests: 999999999
            ), whitelisted: false, blacklisted: false))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraSmall)
            .environment(\.colorScheme, .dark)
            .background(Color.black)

            ActivityItemView(vm: ActivityItemViewModel(entry: HistoryEntry(
                name: "super.long.domain.name.com",
                type: .blocked,
                time: Date(timeIntervalSinceNow: -5000000),
                requests: 999999
            ), whitelisted: true, blacklisted: false))
            .previewLayout(.sizeThatFits)
            .environment(\.sizeCategory, .extraExtraExtraLarge)
        }
    }
}
