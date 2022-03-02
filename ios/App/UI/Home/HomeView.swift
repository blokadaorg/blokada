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

struct HomeView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var vm = ViewModels.home
    @ObservedObject var contentVM = ViewModels.content

    @State var size: CGFloat = 0.0
    @State var anOpacity = 0.6

    @State var showHelpActions = false

    var tabBar: Bool

    var body: some View {
        ZStack {

            PowerView(vm: self.vm)
            .frame(maxWidth: 196, maxHeight: 196)
            .accessibility(label: Text(
                (self.vm.appState == .Activated) ?
                    L10n.homePowerActionTurnOff : L10n.homePowerActionTurnOn
            ))

            VStack {
                VStack {
                    ZStack {
                        Image(Image.iHeader)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .colorMultiply(.primary)
                        .frame(height: 24)

                        HStack {
                            Text("+")
                                .fontWeight(.heavy)
                                .foregroundColor(Color.cActivePlus)
                                .font(.title)
                        }
                        .offset(x: 100)
                        .transition(.opacity)
                        .opacity(self.vm.appState == .Activated && self.vm.vpnEnabled ? 1.0 : 0.0)
                        .animation(
                            Animation.easeOut(duration: 0.1).repeatCount(2)
                        )
                    }
                    .accessibility(hidden: true)

                    Text(
                        self.vm.working ? "..."
                            : self.vm.timerSeconds > 0 ? L10n.homeStatusPaused.uppercased()
                            : self.vm.appState == .Activated ? L10n.homeStatusActive.uppercased()
                            : L10n.homeStatusDeactivated.uppercased()
                    )
                    .fontWeight(.heavy).kerning(2).padding(.bottom).font(.system(size: 15))
                    .foregroundColor(
                        self.vm.appState != .Activated ? .primary
                        : self.vm.vpnEnabled ? Color.cActivePlus
                        : Color.cActive
                    )
                    .fixedSize()
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                .padding(.top, 72)

                Spacer()

                VStack {
                    VStack {
                        ZStack {
                            // "Tap to activate" text
                            Text(L10n.homeActionTapToActivate)
                                .opacity(!self.vm.working && self.vm.appState != .Activated && self.vm.timerSeconds == 0 ? 1 : 0)
                                .onTapGesture {
                                    if self.vm.working {
                                    } else if !self.vm.accountActive {
                                        self.contentVM.showSheet(.Payment)
                                    } else if !self.vm.dnsPermsGranted {
                                        self.contentVM.showSheet(.Activated)
                                    } else if !self.vm.vpnPermsGranted && self.vm.accountType == .Plus {
                                        self.contentVM.showSheet(.Activated)
                                    } else if self.vm.appState == .Activated {
                                        self.contentVM.showSheet(.AdsCounter)
                                    } else if self.vm.appState == .Paused {
                                        self.vm.unpause()
                                    }
                                }

                            // "Paused" text
                            Text(L10n.homeStatusDetailPaused)
                            .opacity(self.vm.timerSeconds > 0 ? 1 : 0)

                            // "x ads and trackers blocked" text + protecting privacy (vpn)
                            VStack {
                                if self.vm.blockedCounter <= 1 {
                                    L10n.homeStatusDetailActive.withBoldSections(color: Color.cActivePlus)
                                } else {
                                    L10n.homeStatusDetailActiveWithCounter(String(self.vm.blockedCounter.compact))
                                        .withBoldSections(color: Color.cActivePlus)
                                }

                                L10n.homeStatusDetailPlus.withBoldSections(color: Color.cActivePlus)
                            }
                            .opacity(self.vm.appState == .Activated && self.vm.vpnEnabled && !self.vm.working &&  self.vm.timerSeconds == 0 ? 1 : 0)
                            .onTapGesture {
                                self.contentVM.showSheet(.AdsCounter)
                            }

                            // "x ads and trackers blocked" text (cloud only)
                            VStack {
                                if self.vm.blockedCounter <= 1 {
                                    L10n.homeStatusDetailActive.withBoldSections(color: Color.cActive)
                                } else {
                                    L10n.homeStatusDetailActiveWithCounter(String(self.vm.blockedCounter.compact))
                                    .withBoldSections(color: Color.cActive)
                                }
                            }
                            .opacity(self.vm.appState == .Activated && !self.vm.vpnEnabled && !self.vm.working && self.vm.timerSeconds == 0 ? 1 : 0)
                            .onTapGesture {
                                self.contentVM.showSheet(.AdsCounter)
                            }

                            // "In progress" text
                            Text(L10n.homeStatusDetailProgress)
                                .frame(width: 240, height: 96)
                                .background(Color.cBackground)
                                .opacity(self.vm.working ? 1 : 0)
                        }
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                    }
                    .frame(width: 280, height: 96, alignment: .top)
                    .accessibility(hidden: true)

                    PlusButtonView(vm: self.vm)
                        .frame(maxWidth: 500)
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cSemiTransparent)
                )
                .padding([.leading, .trailing, .bottom], 8)
            }
            .padding(.bottom, self.safeAreaInsets.bottom)
            .padding(.bottom, self.tabBar ? TAB_VIEW_HEIGHT : 0)

            // Help icon in top right
            VStack {
                HStack {
                    Spacer()

                    Image(systemName: Image.fHelp)
                        .imageScale(.medium)
                        .foregroundColor(.primary)
                        .frame(width: 36, height: 36, alignment: .center)
                        .padding(12)
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
//        .background(
//            LinearGradient(gradient: Gradient(colors: [Color.cHomeBackground, Color.cBackground]), startPoint: .top, endPoint: .bottom)
//        )
//        .onAppear {
//            self.vm.onAccountExpired = { self.activeSheet = nil }
//        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let error = HomeViewModel()
        error.error = "This is some very long error very long error very long error"
        error.showError = true

        return Group {
            HomeView(tabBar: true)
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))

            HomeView(vm: error, tabBar: false)
            .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
