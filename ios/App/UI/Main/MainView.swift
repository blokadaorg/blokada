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

struct MainView: View {

    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var tabVM = ViewModels.tab

    @State var showHelpActions = false

    @State var startPoint = UnitPoint(x: 0, y: 0)
    @State var endPoint = UnitPoint(x: 0, y: 2)

    var body: some View {
        VStack {
            ZStack {
                HomeView()
                    .opacity(self.tabVM.activeTab == "home" ? 1 : 0)
                ActivityTabView()
                    .opacity(self.tabVM.activeTab == "activity" ? 1 : 0)
                PacksView()
                    .opacity(self.tabVM.activeTab == "packs" ? 1 : 0)
                SettingsTabView()
                    .opacity(self.tabVM.activeTab == "more" ? 1 : 0)

                VStack {
                    HStack {
                        Spacer()

                        Button(action: {
                            withAnimation {
                                self.contentVM.showSheet(.Help)
                            }
                        }) {
                            Image(systemName: Image.fHelp)
                                .imageScale(.medium)
                                .foregroundColor(.primary)
                                .frame(width: 32, height: 32, alignment: .center)
                                .padding(8)
                                .padding(.top, 25)
                                .onTapGesture {
                                    self.showHelpActions = true
                                }
                                .actionSheet(isPresented: $showHelpActions) {
                                    ActionSheet(title: Text(L10n.accountSupportActionHowHelp), buttons: [
                                        .default(Text(L10n.accountSupportActionKb)) {
                                            Links.openInBrowser(Links.knowledgeBase())
                                        },
                                        .default(Text(L10n.universalActionContactUs)) {
                                            Links.openInBrowser(Links.support())
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
                    }
                    Spacer()
                }
            }
            TabView()
        }
    }
}

private func afterDelay(callback: @escaping () -> Void) {
    onBackground {
        sleep(3)
        onMain {
            callback()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        return Group {
            MainView()
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            .environment(\.colorScheme, .dark)

            MainView()
            .environment(\.sizeCategory, .accessibilityExtraLarge)
            .environment(\.colorScheme, .dark)

            MainView()
        }
    }
}
