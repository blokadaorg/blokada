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

struct CustomV: View {
    @ObservedObject var vm = ViewModels.custom
    @ObservedObject var contentVM = ViewModels.content

    @State private var category: Int = 0

    var body: some View {
        NavigationStack() {
            VStack(spacing: 0) {
                List {
                    CustomAddV(category: $category)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                    
                    if category == 0 {
                        ForEach(self.vm.whitelist, id: \.self) { entry in
                            CustomItemV(item: entry, allowed: true)
                            .contextMenu {
                                Button(action: {
                                    self.vm.delete(entry)
                                }) {
                                    Text(L10n.universalActionDelete)
                                    Image(systemName: Image.fDelete)
                                }
                            }
                        }
                        .onDelete(perform: self.deleteFromWhitelist)
                        .listRowInsets(EdgeInsets())
                    } else if category == 1 {
                        ForEach(self.vm.blacklist, id: \.self) { entry in
                            CustomItemV(item: entry, allowed: false)
                            .contextMenu {
                                Button(action: {
                                    self.vm.delete(entry)
                                }) {
                                    Text(L10n.universalActionDelete)
                                    Image(systemName: Image.fDelete)
                                }
                            }
                        }
                        .onDelete(perform: self.deleteFromBlocklist)
                        .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationBarTitle(L10n.userdeniedSectionHeader)
            .navigationBarItems(trailing:
                Button(action: {
                    self.contentVM.stage.dismiss()
                }) {
                    Text(L10n.universalActionDone)
                }
                .contentShape(Rectangle())
            )
        }
        .accentColor(Color.cAccent)
    }

    func deleteFromWhitelist(_ index: IndexSet) {
        let item = vm.whitelist[index.first!]
        vm.delete(item)
    }

    func deleteFromBlocklist(_ index: IndexSet) {
        let item = vm.blacklist[index.first!]
        vm.delete(item)
    }
}

struct CustomV_Previews: PreviewProvider {
    static var previews: some View {
        CustomV()
    }
}
