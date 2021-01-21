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

    @ObservedObject var vm: HomeViewModel

    @Binding var activeSheet: ActiveSheet?

    @State var size: CGFloat = 0.0
    @State var anOpacity = 0.6

    var body: some View {
        ZStack {
            ZStack {
                // Temporary disabled the rays, to see if they cause the ios14 screen animation issue
//                Circle()
//                    .stroke(lineWidth: 1)
//                    .foregroundColor(.primary)
//                    .opacity(anOpacity)
//                    .scaleEffect(size)
//                    .onAppear() {
//                        withAnimation(Animation.easeInOut(duration: 4).repeatForever(autoreverses: false)) {
//                            self.size = 1.0
//                            self.anOpacity = 0.0
//                        }
//                    }

                // Hides the animated rays if not active
                Rectangle()
                    .fill(Color.cBackground)
                    .opacity(self.vm.mainSwitch && !self.vm.showError && !self.vm.working && self.vm.timerSeconds == 0 ? 0 : 1)
                    .transition(.opacity)
                    .animation(Animation.easeIn(duration: 0.2))

                PowerView(vm: self.vm, activeSheet: self.$activeSheet)
                    .frame(maxWidth: 170, maxHeight: 170)
            }

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
                        .opacity(self.vm.mainSwitch && self.vm.vpnEnabled ? 1.0 : 0.0)
                        .animation(
                            Animation.easeOut(duration: 0.1).repeatCount(2)
                        )
                    }

                    Text(
                        self.vm.working ? "..."
                            : self.vm.timerSeconds > 0 ? L10n.homeStatusPaused.uppercased()
                            : self.vm.mainSwitch ? L10n.homeStatusActive.uppercased()
                            : L10n.homeStatusDeactivated.uppercased()
                    )
                    .fontWeight(.heavy).kerning(2).padding(.bottom).font(.system(size: 15))
                    .foregroundColor(
                        !self.vm.mainSwitch ? .primary
                        : self.vm.vpnEnabled ? Color.cActivePlus
                        : Color.cActive
                    )
                    .fixedSize()
                    .frame(minWidth: 0, maxWidth: .infinity)
                }
                .padding(.top, 72)

                Spacer()

                VStack {
                    ZStack {
                        Text(L10n.homeActionTapToActivate)
                            .opacity(!self.vm.working && !self.vm.mainSwitch && !self.vm.showError ? 1 : 0)
                            .onTapGesture {
                                // Copypaste from PowerView
                                self.vm.mainSwitch = true
                                self.vm.switchMain(activate: self.vm.mainSwitch,
                                    noPermissions: {
                                        // A callback trigerred when there is no VPN profile
                                        self.activeSheet = .askvpn
                                    },
                                    showRateScreen: {
                                        self.activeSheet = .rate
                                    }
                                )
                            }

                        (
                            Text(L10n.homeStatusDetailPaused)
                        )
                        .opacity(self.vm.timerSeconds > 0 ? 1 : 0)

                        VStack {
                            if self.vm.blockedCounter <= 1 {
                                L10n.homeStatusDetailActive.withBoldSections(color: Color.cActivePlus)
                            } else {
                                L10n.homeStatusDetailActiveWithCounter(String(self.vm.blockedCounter.compact))
                                    .withBoldSections(color: Color.cActivePlus, font: .system(size: 18, design: .monospaced))
                            }

                            L10n.homeStatusDetailPlus.withBoldSections(color: Color.cActivePlus)
                        }
                        .opacity(self.vm.mainSwitch && self.vm.vpnEnabled && !self.vm.working && !self.vm.showError && self.vm.timerSeconds == 0 ? 1 : 0)
                        .onTapGesture {
                            self.activeSheet = .counter
                        }

                        VStack {
                            if self.vm.blockedCounter <= 1 {
                                L10n.homeStatusDetailActive.withBoldSections(color: Color.cActive)
                            } else {
                                L10n.homeStatusDetailActiveWithCounter(String(self.vm.blockedCounter.compact))
                                .withBoldSections(color: Color.cActive, font: .system(size: 18, design: .monospaced))
                            }
                        }
                        .opacity(self.vm.mainSwitch && !self.vm.vpnEnabled && !self.vm.working && !self.vm.showError && self.vm.timerSeconds == 0 ? 1 : 0)
                        .onTapGesture {
                            self.activeSheet = .counter
                        }

                        Text(L10n.homeStatusDetailProgress)
                            .frame(width: 240, height: 96)
                            .background(Color.cBackground)
                            .opacity(self.vm.working ? 1 : 0)
                    }
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                }
                .frame(width: 280, height: 96, alignment: .top)

                PlusButtonView(vm: self.vm, activeSheet: self.$activeSheet)
                    .frame(maxWidth: 500)
            }
        }
        .background(Color.cBackground)
        .onAppear {
            self.vm.ensureAppStartedSuccessfully { _, _ in }
            self.vm.onAccountExpired = { self.activeSheet = nil }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let error = HomeViewModel()
        error.error = "This is some very long error very long error very long error"
        error.showError = true

        return Group {
            HomeView(
                vm: HomeViewModel(),
                activeSheet: .constant(nil)
            )
            .previewDevice(PreviewDevice(rawValue: "iPhone X"))

            HomeView(
                vm: error,
                activeSheet: .constant(nil)
            )
            .environment(\.locale, .init(identifier: "pl"))
        }
    }
}
