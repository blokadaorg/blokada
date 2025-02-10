//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2024 Blocka AB. All rights reserved.
//
//  @author Kar
//

import SwiftUI
import CodeScanner
import Factory

struct ScanQrCodeView: View {

    @Injected(\.commands) var commands

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
               //self.showError = true
           }

           print("Scanning failed: \(error.localizedDescription)")
       }
   }

    var body: some View {
        AccountChangeScanView(isShowingScanner: self.$isShowingScanner, handleScan: self.handleScan)
    }
}
