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

struct TagView: View {

    let text: String
    let active: Bool

    var body: some View {
        HStack {
            Text(text.trTag())
              .font(.footnote)
              .foregroundColor(.primary)
        }
        .padding([.leading, .trailing], 14)
      .padding(.top, 4)
      .padding(.bottom, 4)
      .background(
          RoundedRectangle(cornerRadius: 4)
            .fill(self.active ? Color.cAccent : Color(UIColor.systemGray5))
      )
        .padding(.bottom, 8)
    }
}

struct TagView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TagView(text: "ads", active: false)
                .previewLayout(.sizeThatFits)
            TagView(text: "trackers", active: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
