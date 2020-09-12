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
                                NavigationLink(destination: PackDetailView(packsVM: self.vm, vm: PackDetailViewModel(pack: pack)), tag: pack.id, selection: self.$tabVM.selection) {
                                    EmptyView()
                                }
                                    .hidden()
                                PackView(packsVM: self.vm, vm: PackDetailViewModel(pack: pack))
                            }
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
