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

struct ButtonView: View {

    @Binding var enabled: Bool
    @Binding var plus: Bool

    var body: some View {
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(enabled ? (plus ? Color.cAccent : Color.cActive) : Color.cSecondaryBackground, lineWidth: 2)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(enabled ? (plus ? Color.cAccent : Color.cActive) : Color(UIColor.systemGray4))
        }
    }
}

struct ButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ButtonView(enabled: .constant(true), plus: .constant(false)).previewLayout(.fixed(width: 200, height: 40))
                .frame(width: 200, height: 44)
            ButtonView(enabled: .constant(true), plus: .constant(true)).previewLayout(.fixed(width: 200, height: 40))
                .frame(width: 200, height: 44)
            ButtonView(enabled: .constant(false), plus: .constant(true)).previewLayout(.fixed(width: 200, height: 40))
                .frame(width: 200, height: 44)
        }
    }
}
