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

struct PackDetailView: View {

    @ObservedObject var vm: PackDetailViewModel
    @ObservedObject var packsVM = ViewModels.packs
    @ObservedObject var contentVM = ViewModels.content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text(self.vm.pack.meta.title)
                    .font(.system(size: 20))
                    .bold()
                    .padding(.bottom)

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
                            Button(action: {
                                self.vm.changeConfig(config: item, fail: { error in
                                    self.packsVM.showError = true
                                })
                            }) {
                                PackConfigItemView(text: item, active: self.vm.pack.status.config.contains(item))
                            }
                        }
                    }
                }

                Divider()
                    .padding([.top, .bottom])

                VStack(alignment: .leading) {
                    Button(action: {
                        withAnimation {
                            self.contentVM.openLink(self.vm.pack.meta.creditUrl)
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
        }
        .navigationBarTitle(Text(""), displayMode: .inline)
        .accentColor(Color.cAccent)
    }
}

struct PackDetailView_Previews: PreviewProvider {
    static var previews: some View {

        return Group {
            PackDetailView(vm: PackDetailViewModel(pack: Pack.mocked(id: "1", tags: ["ads", "trackers", "regional", "porn", "something"],
                title: "Energized", slugline: "This is a short slug", description: "The best list on the market",
                creditName: "Energized Team", configs: ["Spark", "Blue", "Full"])
                .changeStatus(installed: true, enabledConfig: ["Blue"])
            ))
            PackDetailView(vm: PackDetailViewModel(pack: Pack.mocked(id: "1", tags: [],
                title: "Energized", description: "The best list on the market",
                creditName: "Energized Team")
                .changeStatus(installed: false, installing: true)
            ))
            .environment(\.locale, .init(identifier: "en"))
        }
    }
}
