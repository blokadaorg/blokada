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

struct BadgeView: View {

    let number: Int?

    init() {
        self.number = nil
    }

    init(number: Int) {
        self.number = number
    }

    var body: some View {
        Text(numberToText())
            .foregroundColor(Color.white)
            .font(.caption)
            .padding(6)
            .frame(minWidth: 18)
            .background(
                Circle()
                    .fill(Color.red)
            )
            .offset(y: -3)
    }
}

extension BadgeView {
    func numberToText() -> String {
        if number == nil {
            return " "
        } else if number! > 9 {
            return "9"
        } else {
            return String(number!)
        }
    }
}

struct BadgeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BadgeView()
                .previewLayout(.sizeThatFits)
            BadgeView(number: 1)
                .previewLayout(.sizeThatFits)
            BadgeView(number: 10)
                .previewLayout(.sizeThatFits)
            BadgeView(number: 99)
                .previewLayout(.sizeThatFits)
        }
    }
}
