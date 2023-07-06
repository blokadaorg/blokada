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

struct PacksFilterBarView: View {

    let columns: Int
    @ObservedObject var vm = ViewModels.packs

    var body: some View {
        VStack(alignment: .center) {
            Picker(selection: self.$vm.filtering, label: EmptyView()) {
                Text(L10n.packCategoryHighlights).tag(0)
                Text(L10n.packCategoryActive).tag(1)
                Text(L10n.packCategoryAll).tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())

            if self.vm.filtering == 2 {
                GridStack(count: self.vm.allTags.count, columns: self.columns) { i in
                    TagView(text: self.vm.allTags[i], active: self.vm.isTagActive(self.vm.allTags[i]))
                        .onTapGesture {
                            self.vm.flipTag(self.vm.allTags[i])
                        }
                }
                .padding(.top, 8)
            }
        }
        .padding([.top, .bottom], 8)
    }
}

struct PacksFilterBarView_Previews: PreviewProvider {
    static var previews: some View {
        PacksFilterBarView(columns: 3)
        PacksFilterBarView(columns: 4)
    }
}
