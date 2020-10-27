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

struct SupportView: View {

    @Binding var activeSheet: ActiveSheet?

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
                        self.activeSheet = nil
                        Links.openInBrowser(Links.knowledgeBase())
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
                        self.activeSheet = nil
                        Links.openInBrowser(Links.support())
                    }) {
                        ZStack {
                            ButtonView(enabled: .constant(true), plus: .constant(true))
                                .frame(height: 44)
                            Text(L10n.universalActionContactUs)
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
                    self.activeSheet = nil
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
        SupportView(activeSheet: .constant(nil))
    }
}
