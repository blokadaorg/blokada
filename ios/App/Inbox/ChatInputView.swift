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

struct ChatInputView: View {

    @Binding var input: String
    @State var hint: String = "What can I ask?"

    var body: some View {
        HStack {
            TextField(self.hint, text: $input)

            Button(action: {
                if !self.input.isEmpty {
                    InboxService.shared.newMessage(self.input)
                    self.input = ""
                    UIApplication.shared.endEditing(true)
                }
            }) {
                Image(systemName: "arrow.up")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundColor(Color.white)
                    .padding(8)
                    .background(
                        Circle()
                            .foregroundColor(Color.cAccent)
                    )
            }
        }
        .padding([.top, .bottom], 3)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
        .padding([.leading, .trailing], 8)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

struct ChatInputView_Previews: PreviewProvider {
    static var previews: some View {
        ChatInputView(input: .constant(""))
    }
}
