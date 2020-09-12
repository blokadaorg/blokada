//
//  This file is part of Blokada.
//
//  Blokada is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Blokada is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with Blokada.  If not, see <https://www.gnu.org/licenses/>.
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

                if self.vm.pack.status.badge {
                    BadgeView()
                        .offset(x: 6, y: -26)
                }
            }

            VStack(alignment: .leading) {
                Text(vm.pack.meta.title)
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

struct PackView_Previews: PreviewProvider {
    static var previews: some View {
        PackView(packsVM: PacksViewModel(tabVM: TabViewModel()), vm: PackDetailViewModel(pack: Pack.mocked(id: "1", tags: ["ads", "trackers"],
            title: "Energized", slugline: "The best list on the market",
            creditName: "Energized Team").changeStatus(installed: true, badge: true))
        )
    }
}
