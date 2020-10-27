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

struct AdsCounterShareView: View {

    @ObservedObject var homeVM: HomeViewModel

    @Binding var activeSheet: ActiveSheet?

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
                self.activeSheet = nil
            }) {
                Text(L10n.universalActionDone)
            }.contentShape(Rectangle()),
            trailing: Button(action: {
                self.activeSheet = .sharecounter
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
            AdsCounterShareView(homeVM: vm, activeSheet: .constant(nil))
            AdsCounterShareView(homeVM: vm2, activeSheet: .constant(nil))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
            AdsCounterShareView(homeVM: vm3, activeSheet: .constant(nil))
        }
    }
}
