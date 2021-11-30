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
