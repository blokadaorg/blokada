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

struct PackConfigView: View {

    let text: String

    var body: some View {
         Text(text)
           .bold()
           .font(.subheadline)
            .foregroundColor(.primary)
           .padding(.leading, 18)
           .padding(.trailing, 18)
           .padding(.top, 4)
           .padding(.bottom, 4)
           .background(
               RoundedRectangle(cornerRadius: 8)
                   .fill(Color(UIColor.systemGray5))
           )
    }
}

struct PackConfigView_Previews: PreviewProvider {
    static var previews: some View {
        PackConfigView(text: "Blue")
    }
}
