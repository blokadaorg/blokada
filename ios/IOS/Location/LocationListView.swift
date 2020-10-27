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

struct LocationListView: View {

    @ObservedObject var vm = LocationListViewModel()
    @Binding var activeSheet: ActiveSheet?
    @State var showSpinner = true

    var body: some View {
        return NavigationView {
            ZStack {
                VStack {
                    HStack {
                        Spacer()
                        Text(L10n.errorLocationFailedFetching)
                        Spacer()
                    }
                    .padding(.top, 100)

                    VStack {
                        Button(action: {
                            self.showSpinner = true
                            self.vm.loadGateways {
                                self.showSpinner = false
                            }
                        }) {
                            ZStack {
                                ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)
                                Text(L10n.universalActionTryAgain)
                                    .foregroundColor(.white)
                                    .bold()
                            }
                        }
                    }
                    .padding(40)
                    Spacer()
                }
                .opacity(!self.vm.items.isEmpty ? 1 : 0)
                .frame(maxWidth: 500)

                ScrollView {
                    ZStack(alignment: .top) {
                        VStack {
                            Text(L10n.locationChoiceHeader)
                                .font(.largeTitle)
                                .bold()
                                .padding([.leading, .trailing])

    //                        (
    //                            Text("Our VPN protects you from eavesdropping and tracking.")
    //                        )
    //                        //.multilineTextAlignment(.center)
    //                        .padding([.top, .bottom])
    //                        .padding([.leading, .trailing])

                            ZStack {
                                VStack(spacing: 0) {
                                    ForEach(self.vm.items, id: \.self) { item in
                                        Button(action: {
                                            withAnimation {
                                                self.activeSheet = nil
                                                self.vm.changeLocation(item)
                                            }
                                        }) {
                                            LocationView(vm: item)
                                        }
                                    }
                                }
                                .padding([.leading, .trailing], 20)
                            }

                            Spacer()
                        }
                    }
                    .opacity(self.vm.items.isEmpty ? 0 : 1)
                    .frame(maxWidth: 500)
                }
                .background(Color.cBackground)
                .disabled(self.vm.items.isEmpty)

                VStack {
                    HStack {
                        Spacer()
                        SpinnerView()
                        Spacer()
                    }
                    .padding(.top, 100)
                    Spacer()
                }
                .background(Color.cBackground)
                .opacity(self.showSpinner ? 1.0 : 0.0)
                .transition(.opacity)
                .animation(.easeInOut)
            }

            .navigationBarItems(trailing:
                Button(action: {
                    self.activeSheet = nil
                }) {
                    Text(L10n.universalActionCancel)
                }
                .contentShape(Rectangle())
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            self.vm.loadGateways {
                self.showSpinner = false
            }
        }
    }
}

struct LocationListView_Previews: PreviewProvider {
    static var previews: some View {
        return LocationListView(activeSheet: .constant(nil))
    }
}
