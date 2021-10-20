//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import SwiftUI

struct ActivityTabView: View {

    @ObservedObject var vm: ActivityViewModel
    @ObservedObject var tabVM: TabViewModel

    var body: some View {
        GeometryReader { geo in
            NavigationView {
                ZStack {
                    if self.vm.logRetention != "" {
                        ActivityView(vm: self.vm, tabVM: self.tabVM)
                    } else {
                        NoLogRetentionView(vm: self.vm)
                    }
                }
                .onAppear {
                    self.vm.checkLogRetention()
                }
                .navigationBarTitle(L10n.activitySectionHeader)

                DoubleColumnPlaceholderView()
            }
            .accentColor(Color.cAccent)
            .padding(.leading, geo.size.height > geo.size.width ? 1 : 0) // To force double panel
        }
    }
}

struct ActivityTabView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityTabView(vm: ActivityViewModel(), tabVM: TabViewModel())
    }
}
