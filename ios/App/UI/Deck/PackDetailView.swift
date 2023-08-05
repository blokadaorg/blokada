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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                HStack {
                    PlaceholderView(id: self.vm.pack.id, desaturate: true)
                    .frame(width: 64, height: 64)
                    .mask(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel(self.vm.pack.meta.title)

                    VStack(alignment: .leading) {
                        Text(vm.pack.meta.title)
                        //.foregroundColor(self.vm.selected ? Color.cAccent : Color.primary)
                       // .accessibilitySortPriority(1)

                        Text(
                            vm.pack.meta.slugline.isEmpty ?
                                vm.pack.meta.creditName
                                : vm.pack.meta.slugline.tr()
                        )
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                    }

                    Spacer()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
                
                if !self.vm.pack.meta.description.isEmpty {
                    HStack(spacing: 0) {
                        Text(self.vm.pack.meta.description.tr())
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                    )
                }

                if !self.vm.pack.configs.isEmpty {
                    Text(L10n.packConfigurationsHeader)
                        .font(.system(size: 24))
                        .padding(.top)
                        .bold()

                    VStack(spacing: 0) {
                        ForEach(self.vm.pack.configs, id: \.self) { item in
                            let tag = "\(self.vm.pack.id)/\(item)"
                            if item != self.vm.pack.configs.first {
                                Divider().padding([.top, .bottom], 8)
                            }

                            OptionView(
                                text: item.capitalized,
                                image: Image.fPack,
                                active: self.vm.pack.status.config.contains(tag),
                                canSpin: true,
                                action: {
                                    self.vm.changeConfig(config: item, fail: { error in
                                        self.packsVM.showError = true
                                    })
                                }
                            )
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                    )
                }

                Text(L10n.activityInformationHeader)
                    .font(.system(size: 24))
                    .padding(.top)
                    .bold()

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation {
                            self.contentVM.openLink(self.vm.pack.meta.creditUrl)
                        }
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(L10n.packAuthor)
                                    .foregroundColor(.secondary)
                                    .font(.footnote)
                                Text(self.vm.pack.meta.creditName)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
                )
            }
            .padding()
            .padding(.bottom, 56)
        }
        .background(colorScheme == .dark ? Color.cBackground : Color.cSecondaryBackground)
        .navigationBarTitle(Text(""), displayMode: .inline)
        .accentColor(Color.cAccent)
    }
}

struct PackDetailV_Previews: PreviewProvider {
    static var previews: some View {
        PackDetailView(vm: PackDetailViewModel(packId: "oisd"))
    }
}
