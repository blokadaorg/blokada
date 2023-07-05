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

struct JournalNoBarView: View {

    @ObservedObject var journal = ViewModels.journal

    var body: some View {
        List {
            JournalFilterBarView().id("top-journal")
            JournalListView()
        }
    }
}

struct JournalNoBarView_Previews: PreviewProvider {
    static var previews: some View {
        JournalNoBarView()
    }
}
