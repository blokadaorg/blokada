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

struct PacksWideHorizontalView: View {

    @Environment(\.safeAreaInsets) var safeAreaInsets
    @ObservedObject var vm = ViewModels.packs
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                List {
                    PacksFilterBarView(columns: 4).id("top-packs")

                    ForEach(self.vm.packs, id: \.self) { pack in
                        Button(action: {
                            self.tabVM.setSection(pack.id)
                        }) {
                            PackView(packsVM: self.vm, vm: PackDetailViewModel(packId: pack.id))
                        }
                    }
                }
                .frame(width: 600)
                .padding(.bottom, self.safeAreaInsets.bottom)

                ZStack {
                    if let it = self.vm.sectionStack.first  {
                        PackDetailView(vm: PackDetailViewModel(packId: it))
                    } else {
                        PlaceholderPaneView(title: L10n.mainTabAdvanced)
                    }
                }
                .padding(.top, self.safeAreaInsets.top)
                .background(Color.cBackground)
            }
            TopBarBlurView()
        }
    }
}

struct PacksWideHorizontalView_Previews: PreviewProvider {
    static var previews: some View {
        PacksWideHorizontalView()
    }
}
