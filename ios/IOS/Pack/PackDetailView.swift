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

struct PackDetailView: View {

    @ObservedObject var packsVM: PacksViewModel
    @ObservedObject var vm: PackDetailViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                if !self.vm.pack.meta.slugline.isEmpty {
                    Text(self.vm.pack.meta.slugline.tr())
                        .padding(.bottom)
                }

                if !self.vm.pack.meta.description.isEmpty {
                    Text(self.vm.pack.meta.description.tr())
                }

                if !self.vm.pack.configs.isEmpty {
                    Divider()

                    Text(L10n.packConfigurationsHeader)
                        .font(.system(size: 20))
                        .bold()
                        .padding(.bottom)

                    VStack(spacing: 0) {
                        ForEach(self.vm.pack.configs, id: \.self) { item in
                            PackConfigItemView(text: item, active: self.vm.pack.status.config.contains(item))
                                .onTapGesture {
                                    self.vm.changeConfig(config: item, fail: { error in
                                        self.packsVM.showError = true
                                    })
                                }
                        }
                    }
                }

                Divider()
                    .padding([.top, .bottom])

                VStack(alignment: .leading) {
                    Button(action: {
                        withAnimation {
                           self.vm.openCreditUrl()
                      }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(L10n.packAuthor)
                                    .foregroundColor(.secondary)
                                Text(self.vm.pack.meta.creditName)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .font(.footnote)
                .padding(.bottom, 10)
            }
            .padding()
            .onAppear {
                self.vm.unsetBadge()
            }
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
    }
}

struct PackDetailView_Previews: PreviewProvider {
    static var previews: some View {

        return Group {
            PackDetailView(packsVM: PacksViewModel(tabVM: TabViewModel()), vm: PackDetailViewModel(pack: Pack.mocked(id: "1", tags: ["ads", "trackers", "regional", "porn", "something"],
                title: "Energized", slugline: "This is a short slug", description: "The best list on the market",
                creditName: "Energized Team", configs: ["Spark", "Blue", "Full"])
                .changeStatus(installed: true, enabledConfig: ["Blue"])
            ))
            PackDetailView(packsVM: PacksViewModel(tabVM: TabViewModel()), vm: PackDetailViewModel(pack: Pack.mocked(id: "1", tags: [],
                title: "Energized", description: "The best list on the market",
                creditName: "Energized Team")
                .changeStatus(installed: false, installing: true)
            ))
            .environment(\.locale, .init(identifier: "en"))
        }
    }
}
