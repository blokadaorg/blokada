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

    let id: String
    let icon: String
    let text: String
    let badge: Int?

    @Binding var active: String

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                if self.icon == "blokada" {
                    Rectangle()
                        .fill(self.active == self.id ? Color.cAccent : .primary)
                        .frame(width: 20, height: 20)
                        .mask(
                            Image(Image.iBlokada)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        )
                } else {
                    Image(systemName: self.icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                }

                Text(self.text)
                    .font(.system(size: 12))
                    .offset(y: -2)
            }
            .foregroundColor(self.active == self.id ? Color.cAccent : .primary)

            if self.badge != nil && self.badge! > 0 {
                BadgeView(number: self.badge!)
                    .offset(y: -8)
            }
        }
        .frame(minWidth: 74)
        .onTapGesture {
            self.active = self.id
        }
    }
}

struct TabItemView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TabItemView(id: "inbox", icon: "tray.and.arrow.down", text: "Inbox", badge: nil, active: .constant("inbox"))
                .previewLayout(.sizeThatFits)
            TabItemView(id: "inbox", icon: "tray.and.arrow.down", text: "Inbox", badge: nil, active: .constant("home"))
                .previewLayout(.sizeThatFits)
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
                .background(Color.black)
            TabItemView(id: "inbox", icon: "blokada", text: "Home", badge: nil, active: .constant("inbox"))
                .previewLayout(.sizeThatFits)
            TabItemView(id: "inbox", icon: "cube.box", text: "Packs", badge: 69, active: .constant("home"))
                .previewLayout(.sizeThatFits)
        }
        .padding()
    }
}
