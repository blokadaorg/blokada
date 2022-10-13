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

    @State var showHelpActions = false

    var body: some View {
        // Help icon in top right
        VStack {
            HStack {
                Spacer()

                Image(systemName: Image.fHelp)
                    .imageScale(.medium)
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36, alignment: .center)
                    .padding(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.showHelpActions = true
                    }
                    .actionSheet(isPresented: $showHelpActions) {
                        ActionSheet(title: Text(L10n.accountSupportActionHowHelp), buttons: [
                            .default(Text(L10n.accountSupportActionKb)) {
                                self.contentVM.openLink(Link.KnowledgeBase)
                            },
                            .default(Text(L10n.universalActionContactUs)) {
                                self.contentVM.openLink(Link.Support)
                            },
                            .default(Text(L10n.universalActionShowLog)) {
                                self.contentVM.showSheet(.ShowLog)
                            },
                            .default(Text(L10n.universalActionShareLog)) {
                                self.contentVM.showSheet(.ShareLog)
                            },
                            .cancel()
                        ])
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
