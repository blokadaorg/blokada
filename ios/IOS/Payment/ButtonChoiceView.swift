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

struct ButtonChoiceView: View {

    @State var product: Product

    var on: Bool {
        false
    }

    var body: some View {
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(on ? Color.cAccent : Color.cSecondaryBackground, lineWidth: 2)

            HStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(on ? Color.cAccent : Color.cSecondaryBackground)
                    .frame(width: 64)
                Spacer()
            }

            HStack {
                Rectangle()
                    .fill(on ? Color.cAccent : Color.cSecondaryBackground)
                    .frame(width: 60)
                    .padding(.leading, 4)
                Spacer()
            }

            HStack {
                Circle()
                    .fill(Color.cPrimaryBackground)
                    .frame(width: 12)
                    .padding(.leading, 26)
                Spacer()
            }

            HStack {
                Circle()
                    .fill(on ? Color.cAccent : Color.cPrimaryBackground)
                    .frame(width: 8)
                    .padding(.leading, 28)
                Spacer()
            }
        }
    }
}

struct ButtonChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        ButtonChoiceView(product: Product(id: "id", title: "Product 1", description: "Description", price: "49.99", period: 9, type: "plus", trial: false)).previewLayout(.fixed(width: 200, height: 50))

        ButtonChoiceView(product: Product(id: "id", title: "Product 1", description: "Description", price: "49.99", period: 9, type: "cloud", trial: false)).previewLayout(.fixed(width: 200, height: 50))
    }
}
