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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Image(systemName: Image.fInfo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                .foregroundColor(Color.secondary)
                .padding(.trailing)
                
                Text(L10n.accountLeaseLabelDevicesList)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .foregroundColor(colorScheme == .dark ? Color.cSecondaryBackground : Color.cBackground)
            )
            .padding()

            List {
                if self.vm.leases.isEmpty {
                    HStack {
                        Text(L10n.packTagsNone)
                            .foregroundColor(.secondary)
                            .padding()
                        Spacer()
                    }
                } else {
                    ForEach(self.vm.leases, id: \.self) { lease in
                        VStack {
                            OptionView(
                                text: getLeaseName(lease),
                                image: Image.fDevices,
                                active: false,
                                action: {
                                    
                                }
                            )
                            .contextMenu {
                                Button(action: {
                                    //self.vm.deleteLease(entry)
                                }) {
                                    Text(L10n.universalActionDelete)
                                    Image(systemName: Image.fDelete)
                                }
                            }
                        }
                    }
                    .onDelete(perform: self.vm.deleteLease)
                }
            }
            
        }
        .padding(.bottom, 56)
        .background(colorScheme == .dark ? Color.cBackground : Color.cSecondaryBackground)
        .navigationBarTitle(L10n.webVpnDevicesHeader)
        .accentColor(Color.cAccent)
        .onAppear {
            self.vm.refreshLeases()
        }
    }
    
    func getLeaseName(_ lease: LeaseViewModel) -> String {
        if lease.isMe {
            return lease.name + L10n.accountLeaseLabelThisDevice
        } else {
            return lease.name
        }
    }
}

struct LeaseListView_Previews: PreviewProvider {
    static var previews: some View {
        LeaseListView()
    }
}
