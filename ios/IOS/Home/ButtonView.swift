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

struct ButtonView: View {

    @Binding var enabled: Bool
    @Binding var plus: Bool

    var body: some View {
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(plus ? Color.cActivePlus : Color.cActive, lineWidth: 2)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(plus ? Color.cActivePlus : Color.cActive)
                .opacity(enabled ? 1 : 0)
        }
    }
}

struct ButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ButtonView(enabled: .constant(true), plus: .constant(false)).previewLayout(.fixed(width: 200, height: 40))
            ButtonView(enabled: .constant(true), plus: .constant(true)).previewLayout(.fixed(width: 200, height: 40))
            ButtonView(enabled: .constant(false), plus: .constant(true)).previewLayout(.fixed(width: 200, height: 40))
        }
    }
}
