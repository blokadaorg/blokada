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

var TAB_VIEW_HEIGHT = 56.0

struct TabHorizontalView: View {

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
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Spacer()
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
                TabItemView(
                    id: .Settings, icon: "gear", text: L10n.mainTabSettings, badge: nil,
                    onTap: { self.onTap($0) }
                )
                Spacer()
            }
            .padding(.bottom, 2)
        }
        .overlay(
            Rectangle()
            .frame(width: nil, height: 1, alignment: .top)
            .foregroundColor(Color(UIColor.systemGray4)),
            alignment: .top
        )
        .frame(height: TAB_VIEW_HEIGHT)
        .padding(.bottom, self.safeAreaInsets.bottom)
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
            TabHorizontalView(onTap: { _ in })
                .previewLayout(.sizeThatFits)
            TabHorizontalView(vm: packs, onTap: { _ in })
                .previewLayout(.sizeThatFits)
            TabHorizontalView(vm: account, onTap: { _ in })
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            TabHorizontalView(vm: inbox, onTap: { _ in })
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
                .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
                .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
