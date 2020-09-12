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

struct PaymentView: View {

    let vm: PaymentViewModel

    var body: some View {
        return VStack {
            ZStack {
                ButtonView(enabled: .constant(true), plus: .constant(true))

                HStack {
                    Text(self.vm.price).foregroundColor(Color.primary).font(.headline)
                        + Text(" / ").foregroundColor(Color.primary)
                        + Text(self.vm.name).foregroundColor(Color.primary)
                }
            }
            .frame(height: 44)

            Text(self.vm.description).foregroundColor(Color.primary).font(.caption)
        }
        .padding(.bottom, 12)
        .padding(.leading, 8)
        .padding(.trailing, 8)
    }
}

struct PaymentView_Previews: PreviewProvider {
    static var previews: some View {
        PaymentView(vm: PaymentViewModel("Product"))
    }
}
