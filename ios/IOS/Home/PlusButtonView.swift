//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
//
//  Copyright © 2020 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct PlusButtonView: View {

    @ObservedObject var vm: HomeViewModel

    @Binding var activeSheet: ActiveSheet?

    @State var orientationOpacity = 0.0

    var body: some View {
        return ZStack {
            ButtonView(enabled: .constant(!self.vm.vpnEnabled), plus: .constant(true))
            HStack {
                Button(action: {
                    self.activeSheet = self.vm.accountActive ? .location : .plus
                    self.vm.expiredAlertShown = false
                }) {
                    ZStack {
                        HStack {
                            if !self.vm.accountActive {
                                Spacer()
                                L10n.universalActionUpgrade
                                    .toBlokadaPlusText(color: self.vm.vpnEnabled ? Color.primary : Color.white, plusColor: self.vm.vpnEnabled ? Color.primary : Color.white)
                                    .foregroundColor(self.vm.vpnEnabled ? Color.primary : Color.white)
                            } else if !self.vm.vpnEnabled {
                                if !self.vm.hasLease {
                                    Spacer()
                                }

                                L10n.homePlusButtonDeactivated
                                    .toBlokadaPlusText(color: Color.white, plusColor: Color.white)
                                    .foregroundColor(.white)
                            } else if !self.vm.hasSelectedLocation {
                                Spacer()
                                Text(L10n.homePlusButtonSelectLocation)
                                    .foregroundColor(.white)
                            } else {
                                L10n.homePlusButtonLocation(self.vm.location)
                                    .withBoldSections(font: .headline)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                        }
                        .padding(.leading)
                    }
                }
                if self.vm.hasLease {
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.cBackground)
                            .frame(width: 58)

                        Toggle("", isOn: self.$vm.vpnEnabled)
                            .labelsHidden()
                            .frame(width: 64)
                            .padding(.trailing, 4)
                            .onTapGesture {
                                self.vm.switchVpn(activate: !self.vm.vpnEnabled)
                            }
                            //.toggleStyle(SwitchToggleStyle(tint: Color.cAccent))
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(height: 44)
        .padding()
        .transition(.slide)
        .offset(y: self.vm.mainSwitch && !self.vm.isPaused ? 0 : 64)
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
        PlusButtonView(
            vm: HomeViewModel(),
            activeSheet: .constant(nil)
        )
    }
}
