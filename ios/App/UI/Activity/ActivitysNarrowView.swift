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

struct ActivitysNarrowView: View {

    @ObservedObject var vm = ViewModels.activity

    var body: some View {
        GeometryReader { geo in
            NavigationView {
                ZStack {
                    if self.vm.logRetention != "" {
                        ActivitysView()
                    } else {
                        NoLogRetentionView()
                    }
                }
                .navigationBarTitle(L10n.activitySectionHeader)

            }
            .accentColor(Color.cAccent)
            .padding(.leading, geo.size.height > geo.size.width ? 1 : 0) // To force double panel
        }
    }
}

struct ActivitysNarrowView_Previews: PreviewProvider {
    static var previews: some View {
        ActivitysNarrowView()
    }
}