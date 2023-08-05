//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2023 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI
import CodeScanner
import Factory

struct AccountChangeView: View {
    @ObservedObject var vm = ViewModels.account
    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var homeVM = ViewModels.home
    
    @Environment(\.colorScheme) var colorScheme
    @Injected(\.commands) var commands
    
    @State var appear = false
    @State var showError = false
    
    @State private var token: String = ""
    @State private var isShowingScanner = false

    func handleScan(result: Result<ScanResult, ScanError>) {
       switch result {
       case .success(let code):
           self.isShowingScanner = false  // dismiss the scanner view
           self.token = code.string
           self.commands.execute(CommandName.url, self.token)
       case .failure(let error):
           self.isShowingScanner = false

           DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
               self.showError = true
           }

           print("Scanning failed: \(error.localizedDescription)")
       }
   }

    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Text(L10n.familyAccountAttachHeader)
                        .font(.largeTitle)
                        .bold()
                        .padding()
                        .padding([.top], 24)

                    Text(L10n.familyAccountAttachBody)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding(.top, 24)
                    .padding(.bottom, 56)

                    HStack(spacing: 0) {
                        Image(systemName: "qrcode.viewfinder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                        .foregroundColor(Color.accentColor)
                        .padding(.trailing) 

                        VStack(alignment: .leading) {
                            Text(L10n.familyAccountQrHeader)
                            .fontWeight(.medium)
                            Text(L10n.familyAccountQrBody)
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                        .onTapGesture {
                            self.isShowingScanner = true
                        }
                        Spacer()
                    }
                    .padding(.bottom, 40)

                    Spacer()

                    VStack {
                        Button(action: {
                            self.isShowingScanner = true
                        }) {
                            ZStack {
                                ButtonView(enabled: .constant(true), plus: .constant(true))
                                    .frame(height: 44)
                                HStack {
                                    Image(systemName: "qrcode.viewfinder")
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.white)
                                    Text(L10n.familyAccountQrActionButton)
                                        .foregroundColor(.white)
                                        .bold()
                                }
                            }
                        }
                        .sheet(isPresented: self.$isShowingScanner) {
                            AccountChangeScanView(isShowingScanner: self.$isShowingScanner, handleScan: self.handleScan)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: 500)
                .navigationBarItems(trailing:
                    Button(action: {
                        self.contentVM.stage.dismiss()
                    }) {
                        Text(L10n.universalActionDone)
                    }
                    .contentShape(Rectangle())
                )
            }
            .padding([.leading, .trailing], 40)
            .alert(isPresented: self.$showError) {
                Alert(title: Text(L10n.alertErrorHeader), message: Text(L10n.familyStatusPermsBody),
                      dismissButton: Alert.Button.default(
                        Text(L10n.universalActionContinue), action: {
                            self.isShowingScanner = false
                            openAppSettings()
                        }
                    )
                )
            }
        }
        .opacity(self.appear ? 1 : 0)
        .navigationViewStyle(StackNavigationViewStyle())
        .accentColor(Color.cAccent)
        .onAppear {
            self.appear = true
        }
    }
    
    func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

struct AccountChangeScanView: View {
    
    @Binding var isShowingScanner: Bool
    let handleScan: (Result<ScanResult, ScanError>) -> Void

    var body: some View {
        ZStack {
            CodeScannerView(codeTypes: [.qr], simulatedData: "mockedmocked", completion: self.handleScan)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: {
                        self.isShowingScanner = false
                    }) {
                        ZStack {
                            Text(L10n.universalActionClose)
                                .foregroundColor(.cAccent)
                        }
                        .padding()
                    }
                }
                .background(Color.black.opacity(0.5))

                Spacer()
            }
            
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                .foregroundColor(Color.black.opacity(0.5))
                .frame(width: 240, height: 240)
        }
    }
}

struct AccountChangeView_Previews: PreviewProvider {
    static var previews: some View {
        AccountChangeView()
        AccountChangeScanView(isShowingScanner: .constant(true), handleScan: {scan in })
    }
}
