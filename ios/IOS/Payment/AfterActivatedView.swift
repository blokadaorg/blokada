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

struct AfterActivatedView: View {

    @Binding var showSheet: Bool
    @Binding var sheet: String
    @State var appear = false

    var body: some View {
        NavigationView {
            VStack {
                BlokadaView(animate: true)
                    .frame(width: 100, height: 100)

                Text(L10n.paymentHeaderActivated)
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Text(L10n.paymentActivatedDescription)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding([.leading, .trailing], 40)
                    .padding([.top, .bottom])

                VStack {
                    Button(action: {
                        self.showSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(1), execute: {
                            self.sheet = "location"
                            self.showSheet = true
                        })
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.paymentActionChooseLocation)
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
                    self.showSheet = false
                }) {
                    Text(L10n.universalActionDone)
                }
                .contentShape(Rectangle())
            )
        }
        .opacity(self.appear ? 1 : 0)
        .animation(.easeInOut)
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            self.appear = true
        }
    }
}

struct AfterActivatedView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AfterActivatedView(showSheet: .constant(true), sheet: .constant(""))
                .previewDevice(PreviewDevice(rawValue: "iPhone X"))
            AfterActivatedView(showSheet: .constant(true), sheet: .constant(""))
                .environment(\.sizeCategory, .extraExtraExtraLarge)
                .environment(\.colorScheme, .dark)
        }
    }
}
