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
import CoreImage.CIFilterBuiltins
import Factory

struct AccountLinkView: View {
    @ObservedObject var vm = ViewModels.account
    @ObservedObject var contentVM = ViewModels.content
    @ObservedObject var homeVM = ViewModels.home

    @Injected(\.family) private var family
    @Injected(\.cloud) private var device
    @Injected(\.commands) private var commands

    @Environment(\.colorScheme) var colorScheme

    let context = CIContext()
    let filter = CIFilter.qrCodeGenerator()

    @State var appear = false
    @State var deviceName = ""

    func generateQRCode(from string: String) -> UIImage {
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }

    var body: some View {
        NavigationView {
            ScrollView {
                ZStack {
                    VStack {
                        Text(L10n.familyAccountLinkHeader)
                            .font(.largeTitle)
                            .bold()
                            .padding()
                            .padding([.top, .bottom], 24)
                        
                        
                        HStack(spacing: 0) {
                            Image(systemName: "iphone")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color.accentColor)
                                .padding(.trailing)
                            
                            VStack(alignment: .leading) {
                                Text(L10n.familyAccountLinkName)
                                    .fontWeight(.medium)
                                HStack {
                                    TextField(L10n.accountIdStatusUnchanged, text: $deviceName)
                                        .autocapitalization(.none)
                                }
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(lineWidth: 2)
                                        .foregroundColor(Color.cSecondaryBackground)
                                )
                                
                            }
                            .font(.subheadline)
                            Spacer()
                        }
                        .padding(.bottom, 30)
                        
                        HStack(spacing: 0) {
                            Image(systemName: "qrcode.viewfinder")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(Color.accentColor)
                                .padding(.trailing)
                            
                            VStack(alignment: .leading) {
                                Text(L10n.familyAccountLinkQrHeader)
                                    .fontWeight(.medium)
                                Text(L10n.familyAccountQrBody)
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                            Spacer()
                        }
                        .padding(.bottom, 40)
                        
                        ZStack {
                            VStack {
                                Image(uiImage: generateQRCode(from: self.family.familyLinkTemplate.replacingOccurrences(of: "NAME", with: self.deviceName)))
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .onChange(of: deviceName) { newValue in
                                        self.commands.execute(.familyWaitForDeviceName, newValue)
                                    }
                            }
                            .padding()
                            //.opacity(1.0)
                            //.animation(.easeIn, value: self.accountId)
                            .onTapGesture {
                                //                            if self.accountId != "" {
                                //                                self.vm.copyAccountIdToClipboard()
                                //                            }
                                
                            }
                            .contextMenu {
                                Button(action: {
                                    //                                if self.accountId != "" {
                                    //                                    self.vm.copyAccountIdToClipboard()
                                    //                                }
                                    UIPasteboard.general.string = self.family.familyLinkTemplate.replacingOccurrences(of: "NAME", with: self.deviceName)
                                }) {
                                    Text(L10n.universalActionCopy)
                                    Image(systemName: Image.fCopy)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        SpinnerView()
                            .frame(width: 24, height: 24)
                            .fixedSize()
                            .padding([.top, .bottom])
                    }
                    .frame(maxWidth: 500)
                    .navigationBarItems(trailing:
                                            Button(action: {
                        self.contentVM.stage.dismiss()
                    }) {
                        Text(L10n.universalActionCancel)
                    }
                        .contentShape(Rectangle())
                    )
                }
                .padding([.leading, .trailing], 40)
            }
            //.opacity(self.appear ? 1 : 0)
            .navigationViewStyle(StackNavigationViewStyle())
            .accentColor(Color.cAccent)
            .onAppear {
                self.deviceName = self.device.nameProposals.randomElement() ?? "Device"
                self.commands.execute(.familyWaitForDeviceName, self.deviceName)
            }
        }
    }
}

struct AccountLinkView_Previews: PreviewProvider {
    static var previews: some View {
        AccountLinkView()
    }
}
