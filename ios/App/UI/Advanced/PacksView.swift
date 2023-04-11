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

struct PacksView: View {

    @ObservedObject var vm = ViewModels.packs
    @ObservedObject var tabVM = ViewModels.tab

    var body: some View {
        List {
            PacksFilterBarView(columns: 3).id("top-packs")
            ForEach(self.vm.packs, id: \.self) { pack in
                ZStack {
                    PackView(packsVM: self.vm, vm: PackDetailViewModel(packId: pack.id))
                }
                .background(
                    NavigationLink("", value: pack.id).opacity(0)
                )
            }
        }
        .alert(isPresented: self.$vm.showError) {
            Alert(title: Text(L10n.alertErrorHeader), message: Text(L10n.errorPackInstall), dismissButton: .default(Text(L10n.universalActionClose)))
        }
    }
}

struct PacksView_Previews: PreviewProvider {
    static var previews: some View {
        PacksView()
    }
}
