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

struct OptionView: View {

    let text: String
    let image: String
    let active: Bool

    let action: () -> Void

    @State private var ongoing = false

    var body: some View {
        Button(action: {
            self.ongoing = true
            startTimer()
            action()
        }) {
            HStack {
                Text(self.text).fontWeight(self.active ? .bold : .regular)

                Spacer()

                if ongoing {
                    ProgressView()
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: self.image)
                        .imageScale(.large)
                        .foregroundColor(self.active ? Color.cAccent : Color.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding([.leading, .trailing])
            .padding([.top, .bottom], 4)
        }
        .accentColor(.primary)
        .onAppear {
            ongoing = false
        }
        .onDisappear {
            ongoing = false
        }
        .onChange(of: active) { _ in
            ongoing = false
        }
    }

    private func startTimer() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            ongoing = false
        }
    }
}

struct OptionView_Previews: PreviewProvider {
    static var previews: some View {
        OptionView(text: "Option", image: Image.fHelp, active: false, action: {})
        OptionView(text: "Option2", image: Image.fAbout, active: true, action: {})
    }
}
