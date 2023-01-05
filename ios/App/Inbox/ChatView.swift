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

struct ChatView: View {

    let message: Message
    let showTime: Bool

//    @State var visible = false

    var body: some View {
        VStack {
            if showTime {
                Text(message.date.humanChat)
                    .font(.caption)
                    .padding(.top, 6)
            }

            HStack {
                if message.isMe {
                    Spacer()
                }
                
                Text(message.text)
                    .foregroundColor(message.isMe ? .white : .primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(10)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(message.isMe ? Color.cAccent : Color(UIColor.systemGray5))
                    )
                    .transition(.opacity)

                if !message.isMe {
                    Spacer()
                }
            }
            .padding(10)
            .padding(.leading, message.isMe ? 50 : 0)
            .padding(.trailing, message.isMe ? 0 : 50)
//            .opacity(visible ? 1 : 0)
//            .transition(.opacity)
//            .animation(.easeIn)
//            .onAppear {
//                self.visible = true
//            }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ChatView(message: Message.fromBlokada("Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing."), showTime: true)
                .previewLayout(.sizeThatFits)
            ChatView(message: Message.fromMe("Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing, Unless required by applicable law or agreed to in writing."), showTime: true)
                .previewLayout(.sizeThatFits)
            ChatView(message: Message.fromMe("Short reply."), showTime: false)
            ChatView(message: Message.fromBlokada("Yes."), showTime: true)
        }
    }
}
