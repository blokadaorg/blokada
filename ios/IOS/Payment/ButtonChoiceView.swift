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
        ButtonChoiceView(product: Product(id: "id", title: "Product 1", description: "Description", price: "49.99", period: 9)).previewLayout(.fixed(width: 200, height: 50))
    }
}
