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

struct InstalledMarkView: View {
    var body: some View {
        ZStack {
            Image(systemName: Image.fCheckmark)
               .resizable()
               .aspectRatio(contentMode: .fit)
                .foregroundColor(Color.white)
               .frame(width: 8, height: 8)
                .offset(x: 7, y: 7)
                .padding(18)
            .background(
                Rectangle()
                    .fill(Color.cAccent)
                    .opacity(0.3)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(45))
                    .offset(x: 21, y: 21)

            )
            .mask(Rectangle())
        }
    }
}

struct InstalledMarkView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            InstalledMarkView()
                .previewLayout(.sizeThatFits)
                .padding()
            InstalledMarkView()
                .previewLayout(.sizeThatFits)
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
                .padding()
        }
    }
}
