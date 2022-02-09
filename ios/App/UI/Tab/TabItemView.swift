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

struct TabItemView: View {

    @ObservedObject var vm = ViewModels.tab

    let id: Tab
    let icon: String
    let text: String
    let badge: Int?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                ZStack {
                    if self.icon == "blokada" {
                        Rectangle()
                            .fill(self.vm.activeTab == self.id ? Color.cAccent : Color.cPrimary)
                            .frame(width: 20, height: 20)
                            .mask(
                                Image(Image.iBlokada)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 20, height: 20)
                            )
                    } else {
                        Image(systemName: self.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                .scaleEffect(self.vm.activeTab == self.id ? 1.1 : 1.0)
                .animation(.easeIn)

                Text(self.text)
                    .font(.system(size: 12))
                    .offset(y: -2)
            }
            .foregroundColor(self.vm.activeTab == self.id ? Color.cAccent : .primary)

            if self.badge != nil && self.badge! > 0 {
                BadgeView(number: self.badge!)
                    .offset(y: -8)
            }
        }
        .frame(minWidth: 74)
        .onTapGesture {
            self.vm.setActiveTab(self.id)
        }
    }
}

struct TabItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TabItemView(id: .Settings, icon: "tray.and.arrow.down", text: "Inbox", badge: nil)
                .previewLayout(.sizeThatFits)
            TabItemView(id: .Settings, icon: "tray.and.arrow.down", text: "Inbox", badge: nil)
                .previewLayout(.sizeThatFits)
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
                .background(Color.black)
            TabItemView(id: .Home, icon: "blokada", text: "Home", badge: nil)
                .previewLayout(.sizeThatFits)
            TabItemView(id: .Home, icon: "blokada", text: "Home", badge: nil)
                .previewLayout(.sizeThatFits)
            TabItemView(id: .Settings, icon: "cube.box", text: "Packs", badge: 69)
                .previewLayout(.sizeThatFits)
        }
        .padding()
    }
}
