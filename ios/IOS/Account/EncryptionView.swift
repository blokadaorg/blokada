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

struct EncryptionView: View {

    @ObservedObject var homeVM: HomeViewModel

    private let selectedDns = Binding<Int>(get: {
        return Dns.hardcoded.firstIndex(of: Dns.load()) ?? 0
    }, set: {
        let selected = Dns.hardcoded[$0]
        selected.persist()
        VpnService.shared.restartTunnel { _, _ in }
    })

    @Binding var showSheet: Bool
    @Binding var sheet: String

    var body: some View {
        Form {
            Section(header: Text(L10n.accountEncryptHeaderLevel)) {
                HStack {
                    Text(L10n.accountEncryptLabelLevel)
                    Spacer()

                    if self.homeVM.working {
                        SpinnerView()
                    } else if self.homeVM.encryptionLevel == 1 {
                        Text(L10n.accountEncryptLabelLevelLow).foregroundColor(Color.red)
                    } else if self.homeVM.encryptionLevel == 2 {
                        Text(L10n.accountEncryptLabelLevelMedium).foregroundColor(Color.cActive)
                    } else {
                        Text(L10n.accountEncryptLabelLevelHigh).foregroundColor(Color.green)
                    }
                }
                .onTapGesture {
                    self.showSheet = true
                    self.sheet = "encryption-explain"
                }
            }

            Section(header: Text(L10n.accountEncryptHeaderExplanation)) {
                Picker(selection: selectedDns, label: Text(L10n.accountEncryptLabelDns)) {
                    ForEach(0 ..< Dns.hardcoded.count) {
                        Text(Dns.hardcoded[$0].label)
                    }
                }
            }

            Section(header: Text(L10n.universalLabelHelp)) {
                HStack {
                    Text(L10n.accountEncryptActionWhatIsDns)
                    Spacer()

                    Button(action: {
                        Links.openInBrowser(Links.whatIsDns())
                    }) {
                        Image(systemName: Image.fInfo)
                            .imageScale(.large)
                            .foregroundColor(Color.cAccent)
                            .frame(width: 32, height: 32)
                    }
                }

                HStack {
                    Text(L10n.accountActionWhyUpgrade)
                    Spacer()

                    Button(action: {
                        Links.openInBrowser(Links.whyVpn())
                    }) {
                        Image(systemName: Image.fInfo)
                            .imageScale(.large)
                            .foregroundColor(Color.cAccent)
                            .frame(width: 32, height: 32)
                    }
                }
            }
        }
        .accentColor(Color.cAccent)
        .navigationBarTitle(L10n.accountEncryptSectionHeader)
    }
}

struct EncryptionView_Previews: PreviewProvider {
    static var previews: some View {
        let working = HomeViewModel()
        working.working = true

        return Group {
            EncryptionView(homeVM: HomeViewModel(), showSheet: .constant(true), sheet: .constant(""))
            EncryptionView(homeVM: working, showSheet: .constant(true), sheet: .constant(""))
        }
    }
}
