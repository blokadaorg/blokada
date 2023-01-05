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

struct InboxView: View {

    @ObservedObject var vm = ViewModels.inbox
    @ObservedObject var tabVM = ViewModels.tab

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
                //self.tabVM.seenInbox()
            }
        //}
    }
}

struct InboxView_Previews: PreviewProvider {
    static var previews: some View {
        InboxView()
    }
}
