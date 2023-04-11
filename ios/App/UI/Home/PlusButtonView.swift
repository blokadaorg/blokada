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

struct PlusButtonView: View {

    @ObservedObject var vm = ViewModels.home
    @ObservedObject var contentVM = ViewModels.content

    @State var orientationOpacity = 0.0

    var body: some View {
        return ZStack {
            ButtonView(enabled: .constant(!self.vm.vpnEnabled), plus: .constant(true))
            HStack {
                Button(action: {
                    self.vm.expiredAlertShown = false

                    if !self.vm.accountActive {
                        self.contentVM.stage.showModal(.payment)
                    } else if self.vm.accountType == .Cloud {
                        self.contentVM.openLink(Link.ManageSubscriptions)
                    } else if !self.vm.vpnPermsGranted {
                        self.contentVM.stage.showModal(.onboarding)
                    } else {
                        self.contentVM.stage.showModal(.plusLocationSelect)
                    }
                }) {
                    ZStack {
                        HStack {
                            if !self.vm.accountActive || self.vm.accountType != .Plus {
                                Spacer()
                                L10n.universalActionUpgrade
                                    .toBlokadaPlusText(color: self.vm.vpnEnabled ? Color.primary : Color.white, plusColor: self.vm.vpnEnabled ? Color.primary : Color.white)
                                    .foregroundColor(self.vm.vpnEnabled ? Color.primary : Color.white)
                                    .font(.system(size: 14))
                            } else if !self.vm.vpnEnabled {
                                if !self.vm.hasSelectedLocation {
                                    Spacer()
                                }

                                Text(L10n.homePlusButtonDeactivatedCloud)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            } else if !self.vm.hasSelectedLocation {
                                Spacer()
                                Text(L10n.homePlusButtonSelectLocation)
                                    .foregroundColor(.white)
                                    .font(.system(size: 14))
                            } else {
                                L10n.homePlusButtonLocation(self.vm.location)
                                    .withBoldSections(font: .system(size: 14))
                                    .foregroundColor(.primary)
                                    .font(.system(size: 14))
                            }
                            Spacer()
                        }
                        .padding(.leading)
                    }
                }
                if self.vm.hasSelectedLocation {
                    Button(action: {
                        self.vm.switchVpn(activate: !self.vm.vpnEnabled)
                    }) {
                        ZStack(alignment: .center) {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.cBackground)
                            .frame(width: 58)

                            if #available(iOS 14.0, *) {
                                Toggle("", isOn: self.$vm.vpnEnabled)
                                .labelsHidden()
                                .frame(width: 64)
                                .padding(.trailing, 4)
                                .toggleStyle(SwitchToggleStyle(tint: Color.cAccent))
                            } else {
                                Toggle("", isOn: self.$vm.vpnEnabled)
                                .labelsHidden()
                                .frame(width: 64)
                                .padding(.trailing, 4)
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(height: 44)
        .padding([.bottom, .leading, .trailing])
        .transition(.slide)
        .offset(y: self.vm.appState == .Activated ? 0 : 240)
        .animation(
            Animation.easeInOut(duration: 0.6).repeatCount(1)
        )
        .disabled(self.vm.working || self.vm.isPaused)
        .opacity(self.orientationOpacity)
        .onAppear {
            self.orientationOpacity = 1.0
        }
    }
}

struct PlusButtonView_Previews: PreviewProvider {
    static var previews: some View {
        PlusButtonView()
    }
}
