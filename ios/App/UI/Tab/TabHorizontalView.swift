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

struct TabHorizontalView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var vm = ViewModels.tab

    var body: some View {
        VStack {
            Rectangle()
                .fill(Color(UIColor.systemGray4))
                .frame(height: 1)
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
                TabItemView(id: .Home, icon: "blokada", text: L10n.mainTabHome, badge: nil)
                TabItemView(id: .Activity, icon: "chart.bar", text: L10n.mainTabActivity, badge: nil)
                TabItemView(id: .Advanced, icon: "cube", text: L10n.mainTabAdvanced, badge: nil)
                TabItemView(id: .Settings, icon: "gear", text: L10n.mainTabSettings, badge: nil)
                Spacer()
            }
            .padding(.bottom, 2)
        }
        .frame(height: 56)
        .padding(.bottom, self.safeAreaInsets.bottom)
        .background(
            .ultraThinMaterial
        )
    }
}

struct TabHorizontalView_Previews: PreviewProvider {
    static var previews: some View {
        let inbox = TabViewModel()
        inbox.activeTab = .Activity

        let packs = TabViewModel()
        packs.activeTab = .Advanced
        //packs.packsBadge = 1

        let account = TabViewModel()
        account.activeTab = .Settings


        return Group {
            TabHorizontalView()
                .previewLayout(.sizeThatFits)
            TabHorizontalView(vm: packs)
                .previewLayout(.sizeThatFits)
            TabHorizontalView(vm: account)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            TabHorizontalView(vm: inbox)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
