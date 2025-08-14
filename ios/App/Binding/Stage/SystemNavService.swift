//
//  This file is part of Blokada.
//
//  This Source Code Form is subject to the terms of the Mozilla Public
//  License, v. 2.0. If a copy of the MPL was not distributed with this
//  file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
//  Copyright © 2021 Blocka AB. All rights reserved.
//
//  @author Karol Gusak
//

import Foundation
import UIKit

class SystemNavService {
    
    private let privateDnsService: PrivateDnsServiceIn
    
    init(privateDnsService: PrivateDnsServiceIn) {
        self.privateDnsService = privateDnsService
    }

    func openSystemSettings() {
        // Check if running on macOS at runtime
        if ProcessInfo.processInfo.isiOSAppOnMac {
            // Running as "Designed for iPad" on Mac
            // First prompt to install DNS profile
            if let macDnsService = privateDnsService as? PrivateDnsServiceMac {
                macDnsService.promptToInstallDNSProfile()
            }
            // Then open network preferences
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.network") {
                UIApplication.shared.open(url)
            }
        } else {
            // Running on actual iOS device
            UIApplication.shared.open(URL(string: "App-Prefs:root=General")!)
        }
    }

    func openAppSettings() {
        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }

    func openInBrowser(_ link: URLComponents) {
        if let url = link.url {
            UIApplication.shared.open(url, options: [:])
        } else {
            BlockaLogger.e("SystemNav", "Could not open link: \(link)")
        }
    }

}
