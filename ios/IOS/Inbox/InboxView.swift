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

struct InboxView: View {

    @ObservedObject var vm: InboxViewModel
    @ObservedObject var tabVM: TabViewModel

    var body: some View {
        //NavigationView {
            VStack {
//                Rectangle()
//                    .foregroundColor(Color.cPrimaryBackground)
//                    .frame(height: 44)

                ScrollView {
    //                    if self.vm.responding {
    //                        ChatView(message: Message.fromBlokada("…"), showTime: false)
    //                    }

                    ForEach(self.vm.messages.reversed(), id: \.self) { message in
                        ChatView(message: message, showTime: message.isMe)
                            .rotationEffect(.radians(.pi))
                            .scaleEffect(x: -1, y: 1, anchor: .center)
                    }
                }
                .animation(nil)
                .rotationEffect(.radians(.pi))
                .scaleEffect(x: -1, y: 1, anchor: .center)

                ChatInputView(input: self.$vm.input)
                    .background(Color.cPrimaryBackground)
            }
            .frame(maxWidth: 500)
            .keyboardAware()
            .navigationBarTitle("Inbox", displayMode: .inline)
            .onAppear {
                self.vm.fetch()
                self.tabVM.seenInbox()
            }
        //}
    }
}

struct InboxView_Previews: PreviewProvider {
    static var previews: some View {
        InboxView(vm: InboxViewModel(), tabVM: TabViewModel())
    }
}
