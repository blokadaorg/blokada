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

struct ActivityFilterBarView: View {

    @ObservedObject var vm = ViewModels.activity
    @ObservedObject var tabVM = ViewModels.tab

    @State private var showFilteringOptions: Bool = false
    @State private var showDevices: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: Image.fDevices)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundColor(self.vm.device == "" ? .primary : Color.cAccent)
                .onTapGesture {
                    self.showDevices = true
                }
                .actionSheet(isPresented: self.$showDevices) {
                    ActionSheet(
                        title: Text(getDevicesText(self.vm.device)),
                        buttons: getDeviceButtons(devices: self.vm.devices, onDevice: {
                            self.vm.device = $0
                        })
                    )
                }

                SearchBar(text: self.$vm.search)

                Image(systemName: Image.fFilter)
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
            //.padding([.leading, .trailing], 9)
        }
        .padding(.bottom, 12)
    }
}

private func getDevicesText(_ device: String) -> String {
    if device == "" {
        return L10n.activityFilterShowingFor(L10n.activityDeviceFilterShowAll)
    } else if device == "." {
        return L10n.activityFilterShowingFor(L10n.appSettingsSectionHeader)
    } else {
        return L10n.activityFilterShowingFor(device)
    }
}

private func getDeviceButtons(
    devices: [String], onDevice: @escaping (String) -> Void
) -> [ActionSheet.Button] {
    var buttons: [ActionSheet.Button] = [
        // "All devices" selector
        .default(Text(L10n.activityDeviceFilterShowAll)) {
            onDevice("")
        },
        // "My device" selector
        .default(Text(L10n.appSettingsSectionHeader)) {
            onDevice(".")
        }
    ]

    // Add all devices except the current one (already pre filtered)
    devices.forEach { device in
        buttons = buttons + [
            .default(Text(device)) {
                onDevice(device)
            }
        ]
    }

    buttons = buttons + [.cancel()]
    return buttons
}

struct ActivityFilterBarView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityFilterBarView()
    }
}
