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

struct TabView: View {

    @ObservedObject var vm: TabViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                TabItemView(id: "home", icon: "blokada", text: L10n.mainTabHome, badge: nil, active: self.$vm.activeTab)
                TabItemView(id: "activity", icon: "chart.bar", text: L10n.mainTabActivity, badge: self.vm.activityBadge, active: self.$vm.activeTab)
                TabItemView(id: "packs", icon: "cube", text: L10n.mainTabAdvanced, badge: self.vm.packsBadge, active: self.$vm.activeTab)
                TabItemView(id: "more", icon: "gear", text: L10n.mainTabSettings, badge: self.vm.settingsBadge, active: self.$vm.activeTab)
                Spacer()
            }
            .padding(.bottom, 2)
        }
        .frame(height: 56)
        .background(
            ZStack {
                Color.cBackgroundNavBar
                VStack {
                    Rectangle()
                        .fill(Color(UIColor.systemGray4))
                        .frame(height: 1)
                    Spacer()
                }
            }
        )
    }
}

struct TabView_Previews: PreviewProvider {
    static var previews: some View {
        let inbox = TabViewModel()
        inbox.activeTab = "activity"

        let packs = TabViewModel()
        packs.activeTab = "packs"
        packs.packsBadge = 1

        let account = TabViewModel()
        account.activeTab = "more"


        return Group {
            TabView(vm: TabViewModel())
                .previewLayout(.sizeThatFits)
            TabView(vm: packs)
                .previewLayout(.sizeThatFits)
            TabView(vm: account)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            TabView(vm: inbox)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
