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

struct BenefitView: View {
    @State var icon: String
    @State var text: String

    var body: some View {
        VStack {
            Image(systemName: icon)
                .imageScale(.large)
                .foregroundColor(.primary)
                .frame(width: 32, height: 32)
            Text(text).font(.system(size: 12))
                .multilineTextAlignment(.center)
                .padding(.top, 3)
        }
        .padding(4)
    }
}

struct BenefitView_Previews: PreviewProvider {
    static var previews: some View {
        BenefitView(icon: "heart", text: "Benefit 1").previewLayout(.sizeThatFits)
    }
}
