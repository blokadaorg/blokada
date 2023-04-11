//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI

struct CustomAddV: View {
    @Binding var category: Int

    @ObservedObject var vm = ViewModels.custom

    @Environment(\.colorScheme) var colorScheme

    @State private var name: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Picker(selection: self.$category, label: EmptyView()) {
                    Text(L10n.userdeniedTabAllowed).tag(0)
                    Text(L10n.userdeniedTabBlocked).tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding([.top], 14)
                .padding([.leading, .trailing], 14)

                HStack(alignment: .center) {
                    HStack(alignment: .center) {
                        Image(systemName: isFocused ? Image.fXmark : "list.dash.header.rectangle")
                        .frame(width: 24, height: 24)
                        .foregroundColor(Color.secondary)
                        .onTapGesture {
                            isFocused.toggle()
                            name = ""
                        }
                        
                        TextField("", text: $name)
                        .focused($isFocused)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onSubmit {
                        }
                    }
                    .padding(4)
                    .padding([.leading, .trailing], 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cTertiaryBackground : Color.cTextFieldBgLight)
                    )

                    Button(category == 0 ? L10n.userdeniedActionAllow : L10n.userdeniedActionBlock, action: {
                        if name.isEmpty {
                            isFocused = true
                        } else if category == 0 {
                            self.vm.allow(name)
                        } else {
                            self.vm.deny(name)
                        }
                        name = ""
                    })
                    .padding(.leading, 8)
                    .buttonStyle(.borderless)
                    .transition(.scaleAndFade)
                    .animation(.easeInOut(duration: 0.3), value: category)
                }
                .padding(.all)
                
                Divider()
                .padding(.leading)
            }
        .accentColor(Color.cAccent)
    }
}

struct CustomAddV_Previews: PreviewProvider {
    static var previews: some View {
        CustomAddV(category: .constant(0))
        CustomAddV(category: .constant(1))
    }
}
