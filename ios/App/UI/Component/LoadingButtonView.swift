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

    @State private var loading = false

    var body: some View {
        Button(action: {
            self.loading = true
            startTimer()
            self.action()
        }) {
            ZStack(alignment: alignTrailing ? .trailing : .leading) {
                Toggle("", isOn: .constant(self.isOn))
                    .labelsHidden()
                    .opacity(loading ? 0 : 1)
                    .animation(.easeInOut, value: loading)
                    .toggleStyle(SwitchToggleStyle(tint: Color.cAccent))

                ProgressView()
                    .opacity(loading ? 1 : 0)
                    .animation(.easeInOut, value: loading)
            }

        }.buttonStyle(BorderlessButtonStyle())
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { _ in
            loading = false
        }
    }
}

struct LoadingButtonView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoadingButtonView(isOn: false)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false)
                .previewLayout(.sizeThatFits)
                .environment(\.colorScheme, .dark)
            LoadingButtonView(isOn: true)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: true)
                .previewLayout(.sizeThatFits)
            LoadingButtonView(isOn: false, alignTrailing: true)
                .previewLayout(.sizeThatFits)
        }
    }
}
