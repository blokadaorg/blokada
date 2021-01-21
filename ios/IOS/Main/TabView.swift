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
