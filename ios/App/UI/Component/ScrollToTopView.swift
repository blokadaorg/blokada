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

struct ScrollToTopView: View {

    let action: () -> Void

    var body: some View {
        VStack(alignment: .trailing) {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    withAnimation() {
                        self.action()
                    }
                }) {
                    Image(systemName: Image.fUp)
                    .imageScale(.large)
                    .foregroundColor(Color.primary)
                    .opacity(0.6)
                    .frame(width: 32, height: 32)
                }
            }
            .padding()
        }
    }
}

struct ScrollToTopView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollToTopView(action: {})
    }
}
