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

struct TabVerticalView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var vm = ViewModels.tab

    let onTap: (Tab) -> Void

    var body: some View {
        if #available(iOS 15.0, *) {
            content.background(.ultraThinMaterial)
        } else {
            content.background(Color.cTertiaryBackground)
        }
    }

    var content: some View {
        HStack {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                TabItemView(
                    id: .Home, icon: "blokada", text: L10n.mainTabHome, badge: nil,
                    onTap: { self.onTap($0) }
                )
                TabItemView(
                    id: .Activity, icon: "chart.bar", text: L10n.mainTabActivity, badge: nil,
                    onTap: { self.onTap($0) }
                )
                TabItemView(
                    id: .Advanced, icon: "cube", text: L10n.mainTabAdvanced, badge: nil,
                    onTap: { self.onTap($0) }
                )
                Spacer()
                TabItemView(
                    id: .Settings, icon: "gear", text: L10n.mainTabSettings, badge: nil,
                    onTap: { self.onTap($0) }
                )
            }
            .padding([.top, .bottom], 16)
            Spacer()
        }
        .padding(.top, self.safeAreaInsets.top)
        .overlay(
            Rectangle()
            .frame(width: 1, height: nil, alignment: .trailing)
            .foregroundColor(Color(UIColor.systemGray4))
            .padding(.trailing, 5), // Idk why it's needed

            alignment: .trailing
        )

        //.padding(.bottom, self.safeAreaInsets.bottom)
        .frame(width: TAB_VIEW_WIDTH)
    }

}

struct TabVerticalView_Previews: PreviewProvider {
    static var previews: some View {
        let inbox = TabViewModel()
        inbox.activeTab = .Activity

        let packs = TabViewModel()
        packs.activeTab = .Advanced
        //packs.packsBadge = 1

        let account = TabViewModel()
        account.activeTab = .Settings


        return Group {
            TabVerticalView(onTap: { _ in })
                .previewLayout(.sizeThatFits)
            TabVerticalView(vm: packs, onTap: { _ in })
                .previewLayout(.sizeThatFits)
            TabVerticalView(vm: account, onTap: { _ in })
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            TabVerticalView(vm: inbox, onTap: { _ in })
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
