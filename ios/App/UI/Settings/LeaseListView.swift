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

struct LeaseListView: View {

    @ObservedObject var vm = ViewModels.lease

    var body: some View {
        Form {
            Section(header: Text(L10n.webVpnDevicesHeader)) {
                Text(L10n.accountLeaseLabelDevicesList)
                .foregroundColor(.secondary)
                .padding()

                List {
                    ForEach(self.vm.leases, id: \.self) { lease in
                        LeaseView(vm: lease)
                    }
                    .onDelete(perform: self.vm.deleteLease)
                }
            }
        }
        .navigationBarTitle(L10n.webVpnDevicesHeader)
        .accentColor(Color.cAccent)
        .onAppear {
            self.vm.refreshLeases()
        }
    }
}

struct LeaseListView_Previews: PreviewProvider {
    static var previews: some View {
        LeaseListView()
    }
}
