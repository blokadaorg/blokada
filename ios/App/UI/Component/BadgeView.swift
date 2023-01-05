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
            .font(.system(size: 9))
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
