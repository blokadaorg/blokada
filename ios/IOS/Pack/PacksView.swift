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

struct PacksView: View {

    @ObservedObject var vm: PacksViewModel
    @ObservedObject var tabVM: TabViewModel

    var body: some View {
        GeometryReader { geo in
            NavigationView {
                VStack {
                    List {
                        VStack(alignment: .leading) {
                            Picker(selection: self.$vm.filtering, label: EmptyView()) {
                                Text(L10n.packCategoryHighlights).tag(0)
                                Text(L10n.packCategoryActive).tag(1)
                                Text(L10n.packCategoryAll).tag(2)
                            }
                            .pickerStyle(SegmentedPickerStyle())

                            if self.vm.filtering == 2 {
                                GridStack(count: self.vm.allTags.count, columns: 3) { i in
                                    TagView(text: self.vm.allTags[i], active: self.vm.isTagActive(self.vm.allTags[i]))
                                        .onTapGesture {
                                            self.vm.flipTag(self.vm.allTags[i])
                                        }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding()

                        ForEach(self.vm.packs, id: \.self) { pack in
                            ZStack {
                                PackView(packsVM: self.vm, vm: PackDetailViewModel(pack: pack))
                            }
                            .background(NavigationLink("", destination: PackDetailView(packsVM: self.vm, vm: PackDetailViewModel(pack: pack)), tag: pack.id, selection: self.$tabVM.selection).opacity(0))
                        }

                    }
                    .alert(isPresented: self.$vm.showError) {
                        Alert(title: Text(L10n.alertErrorHeader), message: Text(L10n.errorPackInstall), dismissButton: .default(Text(L10n.universalActionClose)))
                    }
                }
                .navigationBarTitle(L10n.packSectionHeader)

                DoubleColumnPlaceholderView()
            }
            .accentColor(Color.cAccent)
            .padding(.leading, geo.size.height > geo.size.width ? 1 : 0) // To force double panel
        }
    }
}

struct PacksView_Previews: PreviewProvider {
    static var previews: some View {
        PacksView(vm: PacksViewModel(tabVM: TabViewModel()), tabVM: TabViewModel())
    }
}
