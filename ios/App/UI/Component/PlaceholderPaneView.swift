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

struct PlaceholderPaneView: View {

    let title: String

    var body: some View {
        VStack {
            HStack {
                Text(title)
                .font(.title)
                .bold()
                .padding(.top)

                Spacer()
            }
            .padding(.bottom, 36)

            HStack {
                Text("Use the left pane to select an item.")
                .font(.subheadline)

                Spacer()
            }

            Spacer()
        }
        .padding()
    }
}

struct PlaceholderPaneView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlaceholderPaneView(title: "Settings")
                .previewLayout(.sizeThatFits)
        }
    }
}
