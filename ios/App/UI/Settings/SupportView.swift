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
import Factory

struct SupportView: View {
    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var tabVM = ViewModels.tab

    @Injected(\.commands) private var commands

    var body: some View {
        NavigationView {
            VStack {
                BlokadaView(animate: true)
                    .frame(width: 100, height: 100)

                Text(L10n.accountSupportActionHowHelp)
                    .font(.largeTitle)
                    .bold()
                    .padding()

                VStack {
                    Button(action: {
                        self.contentVM.stage.dismiss()
                        self.contentVM.openLink(Link.KnowledgeBase)
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.accountSupportActionKb)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }

                    Button(action: {
                        self.contentVM.stage.dismiss()
                        self.contentVM.openLink(Link.Support)
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.universalActionContactUs)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }

//                    Button(action: {
//                        self.contentVM.stage.dismiss()
//                        self.contentVM.stage.showModal(.custom)
//                    }) {
//                        ZStack {
//                            ButtonView(enabled: .constant(true), plus: .constant(true))
//                                .frame(height: 44)
//                            Text(L10n.universalActionShareLog)
//                                .foregroundColor(.white)
//                                .bold()
//                        }
//                    }

                    Button(action: {
//                        self.tabVM.setActiveTab(Tab.Home)
//                        self.contentVM.stage.showModal(.debug)
                        self.contentVM.stage.dismiss()
                        self.commands.execute(.shareLog)
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.universalActionShowLog)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }

                    Button(action: {
                        self.contentVM.stage.dismiss()
                        self.contentVM.stage.setRoute("home/rate")
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.mainRateUsHeader)
                                .foregroundColor(.white)
                                .bold()
                        }
                    }
                }
                .padding(40)
            }
            .frame(maxWidth: 500)

            .navigationBarItems(trailing:
                Button(action: {
                    self.contentVM.stage.dismiss()
                }) {
                    Text(L10n.universalActionDone)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
    }
}

struct SupportView_Previews: PreviewProvider {
    static var previews: some View {
        SupportView()
    }
}
