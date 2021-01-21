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

struct LoadingButtonView: View {

    var action = {}

    var isOn: Bool = false
    var alignTrailing: Bool = false

    let loading: Bool

    var body: some View {
        Button(action: {
            self.action()
        }) {
            ZStack(alignment: alignTrailing ? .trailing : .leading) {
                if #available(iOS 14.0, *) {
                    Toggle("", isOn: .constant(self.isOn))
                        .labelsHidden()
                        .opacity(loading ? 0 : 1)
                        .animation(.easeInOut)
                        .toggleStyle(SwitchToggleStyle(tint: Color.cAccent))

                    ProgressView()
                        .opacity(loading ? 1 : 0)
                        .animation(.easeInOut)
                } else {
                    Toggle("", isOn: .constant(self.isOn))
                        .labelsHidden()
                        .opacity(loading ? 0 : 1)
                        .animation(.easeInOut)

                    SpinnerView()
                        .opacity(loading ? 1 : 0)
                        .animation(.easeInOut)
                }
            }

        }.buttonStyle(BorderlessButtonStyle())
    }
}

struct LoadingButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingButtonView(isOn: false, loading: false)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false, loading: false)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            LoadingButtonView(isOn: true, loading: false)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: true, loading: true)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false, alignTrailing: true, loading: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
