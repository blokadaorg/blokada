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

struct ShieldsNarrowView: View {
    @ObservedObject var vm = ViewModels.packs

    var body: some View {
        NavigationStack(path: self.$vm.sectionStack) {
            ShieldsView()
            .navigationTitle(L10n.shieldsSectionHeader)
//            .navigationDestination(for: String.self) { packId in
//                PackDetailView(vm: PackDetailViewModel(packId: packId))
//            }
        }
        .accentColor(Color.cAccent)
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ShieldsNarrowView_Previews: PreviewProvider {
    static var previews: some View {
        ShieldsNarrowView()
    }
}
