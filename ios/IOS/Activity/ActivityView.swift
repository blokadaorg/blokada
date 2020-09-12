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

struct ActivityView: View {

    @ObservedObject var vm: ActivityViewModel
    @ObservedObject var tabVM: TabViewModel

    @State private var showFilteringOptions: Bool = false

    var body: some View {
        GeometryReader { geo in
            NavigationView {
                VStack {
                    List {
                        VStack(alignment: .leading) {
                            HStack {
                                SearchBar(text: self.$vm.search)
                                Image(systemName: "line.horizontal.3.decrease")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(self.vm.filtering == 0 ? .primary : Color.cAccent)
                                    .onTapGesture {
                                        self.showFilteringOptions = true
                                    }
                                .actionSheet(isPresented: self.$showFilteringOptions) {
                                        ActionSheet(title: Text(L10n.activityFilterHeader), buttons: [
                                            .default(Text(L10n.activityFilterShowAll)) {
                                                self.vm.filtering = 0
                                            },
                                            .default(Text(L10n.activityFilterShowBlocked)) {
                                                self.vm.filtering = 1
                                            },
                                            .default(Text(L10n.activityFilterShowAllowed)) {
                                                self.vm.filtering = 2
                                            },
                                            .cancel()
                                        ])
                                    }
                            }
                            Picker(selection: self.$vm.sorting, label: EmptyView()) {
                                Text(L10n.activityCategoryRecent).tag(0)
                               (
                                    Text(self.vm.filtering == 1 ? L10n.activityCategoryTopBlocked : self.vm.filtering == 2 ? L10n.activityCategoryTopAllowed : L10n.activityCategoryTop)
                                ).tag(1)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .padding([.leading, .trailing], 9)
                        }
                        .padding(.bottom, 12)

                        ForEach(self.vm.entries, id: \.self) { entry in
                            ZStack {
                                NavigationLink(destination: ActivityDetailView(vm: ActivityItemViewModel(entry: entry, whitelisted: self.vm.whitelist.contains(entry.name), blacklisted: self.vm.blacklist.contains(entry.name)), activityVM: self.vm), tag: entry.name, selection: self.$tabVM.selection) {
                                    EmptyView()
                                }
                                .hidden()

                                ActivityItemView(vm: ActivityItemViewModel(entry: entry, whitelisted: self.vm.whitelist.contains(entry.name), blacklisted: self.vm.blacklist.contains(entry.name)))
                                    .listRowInsets(EdgeInsets())
                                    .contextMenu {
                                        if self.vm.whitelist.contains(entry.name) {
                                            Button(action: {
                                                self.vm.unallow(entry)
                                            }) {
                                                Text(L10n.activityActionRemoveFromWhitelist)
                                                Image(systemName: "shield.slash")
                                            }
                                        } else if self.vm.blacklist.contains(entry.name) {
                                            Button(action: {
                                                self.vm.undeny(entry)
                                            }) {
                                                Text(L10n.activityActionRemoveFromBlacklist)
                                                Image(systemName: "shield.slash")
                                            }
                                        } else if entry.type == .blocked {
                                            Button(action: {
                                                self.vm.allow(entry)
                                            }) {
                                                Text(L10n.activityActionAddToWhitelist)
                                                Image(systemName: "shield.slash")
                                            }
                                        } else {
                                            Button(action: {
                                                self.vm.deny(entry)
                                            }) {
                                                Text(L10n.activityActionAddToBlacklist)
                                                Image(systemName: "shield.slash")
                                            }
                                        }
                                        Button(action: {
                                            UIPasteboard.general.string = entry.name
                                        }) {
                                            Text(L10n.activityActionCopyToClipboard)
                                            Image(systemName: Image.fCopy)
                                        }
        //                                Button(action: {
        //                                    ShareSheet(activityItems: [entry.name])
        //                                }) {
        //                                    Text("Share")
        //                                    Image(systemName: Image.fShare)
        //                                }
                                    }
                            }
                        }
                    }
                }
                .navigationBarTitle(L10n.activitySectionHeader)

                DoubleColumnPlaceholderView()
            }
            .accentColor(Color.cAccent)
            .padding(.leading, geo.size.height > geo.size.width ? 1 : 0) // To force double panel
        }
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView(vm: ActivityViewModel(), tabVM: TabViewModel())
    }
}
