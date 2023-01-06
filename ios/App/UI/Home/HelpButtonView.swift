//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2022 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI

struct HelpButtonView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets

    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        // Help icon in top right
        VStack {
            HStack {
                Spacer()

                Button(action: {
                    self.contentVM.showSheet(.Help)
                }) {
                    Image(systemName: Image.fHelp)
                        .resizable()
                        .foregroundColor(.primary)
                        .padding(8)
                        .frame(width: 36, height: 36, alignment: .center)
                        .padding(8)
                        .padding(.top, 16)
                        .contentShape(Rectangle())
                }
                .contextMenu {
                    Button(action: {
                        self.contentVM.showSheet(.ShowLog)
                    }) {
                        Text(L10n.universalActionShowLog)
                        Image(systemName: "list.dash")
                    }

                    Button(action: {
                        self.contentVM.showSheet(.ShareLog)
                    }) {
                        Text(L10n.universalActionShareLog)
                        Image(systemName: "square.and.arrow.up")
                    }

                    if !Services.env.isProduction {
                        Button(action: {
                            self.contentVM.showSheet(.Debug)
                        }) {
                            Text("Debug tools")
                            Image(systemName: "ant.circle")
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(.top, self.safeAreaInsets.top)
        .accessibility(hidden: true)
    }
}

struct HelpButtonView_Previews: PreviewProvider {
    static var previews: some View {
        HelpButtonView()
    }
}
