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

struct AdsCounterShareView: View {

    @ObservedObject var homeVM = ViewModels.home
    @ObservedObject var contentVM = ViewModels.content

    @State var point = UnitPoint(x: 1, y: 1)
    @State var counter = 0

    var body: some View {
        NavigationView {
            VStack {
                BlokadaView(animate: true)
                    .frame(width: 100, height: 100)

                Image(Image.iHeader)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .colorMultiply(.primary)
                    .frame(height: 24)
                    .padding()

                Spacer()

                Text(self.counter.compact)
                    .foregroundColor(Color.clear)
                    .font(.system(size: 80, design: .monospaced))
                    .fontWeight(.bold)
                    .overlay(
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cActiveGradient, Color.cActive]),
                                    startPoint: .top, endPoint: point
                                )
                            )
                            .mask(
                                Text(self.counter.compact)
                                    .font(.system(size: 80, design: .monospaced))
                                    .fontWeight(.bold)
                                    .fixedSize()
                                    .frame(width: 200, height: 50)
                            )
//                            .onAppear {
//                                withAnimation(Animation.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
//                                    self.point = UnitPoint(x: 0, y: 0)
//                                }
//                            }
                    )
                    .padding()


                Spacer()

                Text(L10n.homeAdsCounterFootnote)
                    .font(.caption)
                    .padding()
            }
            .frame(maxWidth: 500)
            .navigationBarItems(leading: Button(action: {
                self.contentVM.dismissSheet()
            }) {
                Text(L10n.universalActionDone)
            }.contentShape(Rectangle()),
            trailing: Button(action: {
                self.contentVM.showSheet(.ShareAdsCounter)
            }) {
                Image(systemName: Image.fShare)
                   .imageScale(.large)
                   .foregroundColor(.primary)
                   .frame(width: 32, height: 32)
            }.contentShape(Rectangle()))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            self.counter = 0
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
                if self.counter == self.homeVM.blockedCounter {
                    timer.invalidate()
                } else {
                    var part = self.homeVM.blockedCounter / 10_000
                    part = max(part, 20 * 1) // one second at minimum
                    part = min(part, 20 * 5) // five seconds at maximum

                    var newCounter: Int = self.counter + self.homeVM.blockedCounter / part
                    newCounter = max(newCounter, newCounter + 1)
                    newCounter = min(newCounter, self.homeVM.blockedCounter)
                    self.counter = newCounter > self.homeVM.blockedCounter ? self.homeVM.blockedCounter : newCounter
                }
            }
        }
    }
}

struct AdsCounterShareView_Previews: PreviewProvider {
    static var previews: some View {
        let vm = HomeViewModel()
        vm.blockedCounter = 987987987

        let vm2 = HomeViewModel()
        vm2.blockedCounter = 3

        let vm3 = HomeViewModel()
        vm3.blockedCounter = 100101

        return Group {
            AdsCounterShareView()
            AdsCounterShareView()
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
            AdsCounterShareView()
        }
    }
}
