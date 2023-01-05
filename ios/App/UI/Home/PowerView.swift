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

struct PowerView: View {

    @ObservedObject var vm = ViewModels.home
    @ObservedObject var contentVM = ViewModels.content

    @State var point = UnitPoint(x: 0, y: 0)
    @State var orientationOpacity = 0.0
    @State var showPauseSheet = false

    var body: some View {
        Button(action: {
            withAnimation {
                if self.vm.working {
                } else if !self.vm.accountActive {
                    self.contentVM.showSheet(.Payment)
                } else if !self.vm.dnsPermsGranted {
                    self.contentVM.showSheet(.Activated)
                } else if !self.vm.vpnPermsGranted && self.vm.accountType == .Plus {
                    self.contentVM.showSheet(.Activated)
                } else if self.vm.appState == .Activated {
                    self.showPauseSheet = true
                } else if self.vm.appState == .Paused {
                    self.vm.unpause()
                } else {
                    // At this point app is just active (and user cannot tap this).
                    // Or there is no connectivity and app did not start.
                    // In that case, trigger the flow.
                    self.vm.unpause()
                }
            }
        }) {
            ZStack {
                // Button "cover" in off state
                Circle()
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.white, Color.cPowerButtonGradient]),
                        startPoint: .top, endPoint: .bottom
                    ))
                    .padding(11)
                    .shadow(radius: 5)
                    .opacity(self.vm.appState != .Activated ? 1 : 0)

                // Button icon
                Image(systemName: Image.fPower)
                    .resizable()
                    .foregroundColor(
                        (self.vm.appState != .Activated ? Color.black : self.vm.vpnEnabled ? Color.cActivePlus : Color.cActive)
                    )
                    .padding(71)
                    .opacity(self.vm.working ? 0.2 : 1.0)
                    .transition(.opacity)
                    .animation(
                        Animation.easeInOut(duration: 0.2).repeatCount(1)
                    )

                // The colorful animated ring for libre (blue) mode
                Circle()
                   .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.cActiveGradient, Color.cActive]),
                            startPoint: .top, endPoint: point
                        ), lineWidth: 8
                    )
    //                .onAppear {
    //                    withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
    //                        self.point = UnitPoint(x: 0, y: 1)
    //                    }
    //                }

                // The colorful animated ring for plus (orange) mode
                Circle()
                    .fill(Color.clear)
                    .background (
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cActivePlusGradient, Color.cActivePlus]),
                                    startPoint: .top, endPoint: point
                                ), lineWidth: 8
                            )
    //                        .onAppear {
    //                            withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
    //                                self.point = UnitPoint(x: 0, y: 1)
    //                            }
    //                        }
                    )
                    .opacity(self.vm.vpnEnabled ? 1 : 0)
                    .animation(Animation.easeInOut(duration: 0.9).repeatCount(1))

                // A ring that covers the above to hide colorful rings when off
                Circle()
                    .stroke((self.vm.appState == .Activated || self.vm.timerSeconds > 0) ? Color.clear : Color.cPowerButtonOff, lineWidth: 9)
                    .transition(.opacity)
                    .animation(Animation.easeInOut(duration: 0.9).repeatCount(1))
                    .opacity(self.orientationOpacity)

                // A ring that covers the above for smooth transitions when ongoing state change
                Circle()
                    .stroke(self.vm.working ? Color.primary : Color.clear, lineWidth: 8)
                    .transition(.opacity)
                    .animation(Animation.easeInOut(duration: 0.9).repeatCount(1))
                    .opacity(self.orientationOpacity)

                // A timer that shows up in paused mode
                ZStack {
                    Circle()
                        .fill(Color(UIColor.systemGray6))

                    Circle()
                        .trim(from: CGFloat(300 - self.vm.timerSeconds) / 300, to: 1)
                        .stroke(Color.primary, lineWidth: 8)
                        .rotationEffect(.degrees(-90), anchor: .center)
                        .padding(8)

                    Text(self.vm.timerSeconds.minutesSeconds)
                        .font(.system(size: 36, design: .monospaced))
                        .fontWeight(.bold)
                        .fixedSize()
                        .frame(width: 150, height: 50)

                    Image(systemName: "pause.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(Color.primary)
                        .padding(.top, 88)
                }
                .opacity(self.vm.isPaused ? 1 : 0)
                .animation(Animation.easeInOut(duration: 0.3).repeatCount(1))
            }
            .background(
                ZStack {
                    // Button in on state (pressed in)
                    Circle()
                        .fill(Color(UIColor.systemGray6))
                        .overlay(
                            Circle()
                            .fill(RadialGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black]),
                                center: .center, startRadius: 75, endRadius: 104
                            ))
                            .mask(Circle())
                        )
                        .padding(11)
                }
            )
            .disabled(self.vm.working)
            .onAppear {
                self.orientationOpacity = 1.0
            }
            .actionSheet(isPresented: $showPauseSheet) {
                ActionSheet(title: Text(L10n.homePowerOffMenuHeader), buttons: [
                    .default(Text(self.vm.isPaused ? L10n.homePowerActionTurnOn : L10n.homePowerActionPause)) {
                        if self.vm.isPaused {
                            self.vm.unpause()
                        } else if !self.vm.notificationPermsGranted {
                            self.vm.displayNotificationPermsInstructions()
                        } else {
                            self.vm.pause(seconds: PAUSE_TIME_SECONDS)
                        }
                    },
                    .destructive(Text(L10n.homePowerActionTurnOff)) {
                        self.vm.pause(seconds: nil)
                    },
                    .cancel()
                ])
            }
        }
    }
}

struct PowerView_Previews: PreviewProvider {
    static var previews: some View {
        let off = HomeViewModel()

        let on = HomeViewModel()
        //on.mainSwitch = true

        let timer = HomeViewModel()
        //timer.mainSwitch = true
        timer.startTimer(seconds: 60 * 5 - 60)

        return Group {
            PowerView(vm: off)
                .previewLayout(.fixed(width: 200, height: 200))

            PowerView(vm: on)
                .previewLayout(.fixed(width: 200, height: 200))

            PowerView(vm: off)
                .previewLayout(.fixed(width: 200, height: 200))
                .environment(\.colorScheme, .dark)
                .background(Color.black)

            PowerView(vm: timer)
                .previewLayout(.fixed(width: 200, height: 200))
                .environment(\.colorScheme, .dark)
                .background(Color.black)
        }
    }
}
