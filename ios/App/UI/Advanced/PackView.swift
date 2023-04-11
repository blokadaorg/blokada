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

struct PackView: View {

    @ObservedObject var packsVM: PacksViewModel
    @ObservedObject var vm: PackDetailViewModel

    var body: some View {
        HStack {
            ZStack(alignment: .trailing) {
                PlaceholderView(id: self.vm.pack.id, desaturate: true)
                .frame(width: 64, height: 64)
                .mask(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(self.vm.pack.meta.title)

                if self.vm.pack.status.badge {
                    BadgeView()
                        .offset(x: 6, y: -26)
                }
            }

            VStack(alignment: .leading) {
                Text(vm.pack.meta.title)
                .foregroundColor(self.vm.selected ? Color.cAccent : Color.primary)
                .accessibilitySortPriority(1)

                Text(
                    vm.pack.meta.slugline.isEmpty ?
                        vm.pack.meta.creditName
                        : vm.pack.meta.slugline.tr()
                )
                .font(.footnote)
                .foregroundColor(Color.secondary)
            }

            Spacer()

            LoadingButtonView(action: {
                if !self.vm.pack.status.installed || self.vm.pack.status.updatable {
                    self.vm.install { error in
                        self.packsVM.showError = true
                    }
                } else {
                    self.vm.uninstall { error in
                        self.packsVM.showError = true
                    }
                }
            }, isOn: self.vm.pack.status.installed && !self.vm.pack.status.updatable, alignTrailing: true, loading: self.vm.pack.status.installing)
        }
        .padding(8)
    }
}
