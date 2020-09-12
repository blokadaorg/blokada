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
